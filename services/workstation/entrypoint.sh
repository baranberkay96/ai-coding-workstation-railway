#!/usr/bin/env bash
# AI Coding Workstation entrypoint.
#
# Runs as root under dumb-init:
#   1. prepares the persistent home on the /home volume (first boot seeding,
#      non-recursive ownership repair afterwards),
#   2. exposes selected API keys to SSH sessions,
#   3. optionally starts sshd (key and/or password auth) on $SSH_PORT,
#   4. drops to the unprivileged "coder" user and execs code-server.
set -Eeuo pipefail

WS_USER="coder"
WS_UID="$(id -u "${WS_USER}")"
WS_GID="$(id -g "${WS_USER}")"
WS_HOME="/home/${WS_USER}"
STATE_DIR="/home/.workstation"            # root-only state on the volume (SSH host keys)
INIT_MARKER="${WS_HOME}/.workstation-initialized"
WORKSPACE_DIR="${WORKSPACE_DIR:-${WS_HOME}/workspace}"
CODE_SERVER_PORT="${PORT:-8080}"
SSH_PORT="${SSH_PORT:-2222}"
ENV_FILE="/etc/workstation/env.sh"
MIN_SECRET_LENGTH=12

# Variables copied into SSH login shells (the browser terminal inherits them
# from code-server directly). Extend with WORKSTATION_ENV_PASSTHROUGH.
SHARED_VARS=(
  ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
  OPENAI_API_KEY OPENAI_BASE_URL
  GEMINI_API_KEY GOOGLE_API_KEY GOOGLE_CLOUD_PROJECT
  OPENROUTER_API_KEY
  GITHUB_TOKEN GH_TOKEN
  GIT_USER_NAME GIT_USER_EMAIL
  TZ
)

log() { printf '[workstation] %s\n' "$*"; }
die() { printf '[workstation] ERROR: %s\n' "$*" >&2; exit 1; }

as_user() {
  setpriv --reuid="${WS_UID}" --regid="${WS_GID}" --init-groups \
    env HOME="${WS_HOME}" USER="${WS_USER}" LOGNAME="${WS_USER}" "$@"
}

validate_inputs() {
  [ "$(id -u)" -eq 0 ] || die "the entrypoint must start as root; it drops to ${WS_USER} itself"
  [ -n "${PASSWORD:-}" ] || die "PASSWORD is empty; it protects the browser IDE"
  [ "${#PASSWORD}" -ge "${MIN_SECRET_LENGTH}" ] || die "PASSWORD must be at least ${MIN_SECRET_LENGTH} characters"
  if [ -n "${SSH_PASSWORD:-}" ] && [ "${#SSH_PASSWORD}" -lt "${MIN_SECRET_LENGTH}" ]; then
    die "SSH_PASSWORD must be at least ${MIN_SECRET_LENGTH} characters (or empty to disable password SSH)"
  fi
  case "${SSH_PORT}" in
    ''|*[!0-9]*) die "SSH_PORT must be a number" ;;
  esac
}

prepare_home() {
  mkdir -p "${WS_HOME}"
  if [ ! -f "${INIT_MARKER}" ]; then
    log "first boot: seeding ${WS_HOME} on the persistent volume"
    cp -an /etc/skel/. "${WS_HOME}/"
    mkdir -p "${WS_HOME}/.npm-global" "${WS_HOME}/.local/bin" "${WS_HOME}/.ssh"
    chmod 700 "${WS_HOME}/.ssh"
    chown -R "${WS_UID}:${WS_GID}" "${WS_HOME}"
    date -u +%FT%TZ > "${INIT_MARKER}"
    chown "${WS_UID}:${WS_GID}" "${INIT_MARKER}"
  else
    # Never walk the whole volume on every boot; only repair the top level.
    chown "${WS_UID}:${WS_GID}" "${WS_HOME}"
  fi
  as_user mkdir -p "${WORKSPACE_DIR}"
}

write_env_file() {
  local name names=("${SHARED_VARS[@]}")
  if [ -n "${WORKSTATION_ENV_PASSTHROUGH:-}" ]; then
    IFS=', ' read -r -a extra <<< "${WORKSTATION_ENV_PASSTHROUGH}"
    names+=("${extra[@]}")
  fi
  install -d -m 0755 /etc/workstation
  (
    umask 027
    {
      echo "# Generated at container start from Railway variables. Do not edit."
      for name in "${names[@]}"; do
        [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        if [ -n "${!name:-}" ]; then
          printf 'export %s=%q\n' "${name}" "${!name}"
        fi
      done
    } > "${ENV_FILE}"
  )
  chown "root:${WS_GID}" "${ENV_FILE}"
  chmod 0640 "${ENV_FILE}"
}

configure_git() {
  if [ -n "${GIT_USER_NAME:-}" ]; then as_user git config --global user.name "${GIT_USER_NAME}"; fi
  if [ -n "${GIT_USER_EMAIL:-}" ]; then as_user git config --global user.email "${GIT_USER_EMAIL}"; fi
  if [ -n "${GITHUB_TOKEN:-}${GH_TOKEN:-}" ]; then
    as_user env GITHUB_TOKEN="${GITHUB_TOKEN:-}" GH_TOKEN="${GH_TOKEN:-}" gh auth setup-git >/dev/null 2>&1 \
      || log "gh auth setup-git failed; HTTPS git auth via token not configured"
  fi
}

clone_repo_once() {
  [ -n "${GIT_REPO:-}" ] || return 0
  local target="${WORKSPACE_DIR}/$(basename "${GIT_REPO%.git}")"
  if [ -e "${target}" ]; then
    return 0
  fi
  log "cloning ${GIT_REPO} into ${target}"
  as_user env GITHUB_TOKEN="${GITHUB_TOKEN:-}" GH_TOKEN="${GH_TOKEN:-}" \
    git clone -- "${GIT_REPO}" "${target}" \
    || log "clone failed (check GIT_REPO and GITHUB_TOKEN); continuing without it"
}

setup_ssh() {
  if [ -z "${SSH_PASSWORD:-}" ] && [ -z "${SSH_AUTHORIZED_KEYS:-}" ]; then
    log "SSH disabled (set SSH_PASSWORD and/or SSH_AUTHORIZED_KEYS to enable it)"
    return 0
  fi

  install -d -m 0700 -o root -g root "${STATE_DIR}" "${STATE_DIR}/ssh"
  [ -f "${STATE_DIR}/ssh/ssh_host_ed25519_key" ] \
    || ssh-keygen -q -t ed25519 -N '' -f "${STATE_DIR}/ssh/ssh_host_ed25519_key"
  [ -f "${STATE_DIR}/ssh/ssh_host_rsa_key" ] \
    || ssh-keygen -q -t rsa -b 3072 -N '' -f "${STATE_DIR}/ssh/ssh_host_rsa_key"

  local password_auth="no"
  if [ -n "${SSH_PASSWORD:-}" ]; then
    printf '%s:%s\n' "${WS_USER}" "${SSH_PASSWORD}" | chpasswd
    password_auth="yes"
  else
    usermod -p '*' "${WS_USER}"
  fi

  install -d -m 0755 /etc/ssh/authorized_keys.d
  if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
    printf '%s\n' "${SSH_AUTHORIZED_KEYS}" | tr -d '\r' > "/etc/ssh/authorized_keys.d/${WS_USER}"
    chmod 0644 "/etc/ssh/authorized_keys.d/${WS_USER}"
  else
    rm -f "/etc/ssh/authorized_keys.d/${WS_USER}"
  fi

  cat > /etc/ssh/sshd_config.d/10-workstation.conf <<EOF
# Generated by the workstation entrypoint.
Port ${SSH_PORT}
HostKey ${STATE_DIR}/ssh/ssh_host_ed25519_key
HostKey ${STATE_DIR}/ssh/ssh_host_rsa_key
PermitRootLogin no
AllowUsers ${WS_USER}
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
PasswordAuthentication ${password_auth}
KbdInteractiveAuthentication no
PermitEmptyPasswords no
MaxAuthTries 4
LoginGraceTime 30
ClientAliveInterval 60
ClientAliveCountMax 3
X11Forwarding no
AllowTcpForwarding yes
PrintMotd no
EOF

  mkdir -p /run/sshd
  /usr/sbin/sshd -t || die "sshd configuration test failed"
  log "starting sshd on port ${SSH_PORT} (password auth: ${password_auth}, keys: $([ -n "${SSH_AUTHORIZED_KEYS:-}" ] && echo yes || echo no))"
  (
    while true; do
      /usr/sbin/sshd -D -e || true
      log "sshd exited; restarting in 5s"
      sleep 5
    done
  ) &
}

start_code_server() {
  local salt hash
  salt="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  hash="$(printf '%s' "${PASSWORD}" | argon2 "${salt}" -id -e)"
  cd "${WORKSPACE_DIR}"
  log "starting code-server on 0.0.0.0:${CODE_SERVER_PORT}"
  # Secrets used only for login are removed from the IDE's environment so
  # terminals and AI agents inside the workstation cannot read them.
  exec setpriv --reuid="${WS_UID}" --regid="${WS_GID}" --init-groups \
    env -u PASSWORD -u SSH_PASSWORD -u SSH_AUTHORIZED_KEYS \
      HOME="${WS_HOME}" USER="${WS_USER}" LOGNAME="${WS_USER}" SHELL=/bin/bash \
      HASHED_PASSWORD="${hash}" \
    /usr/bin/code-server \
      --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" \
      --auth password \
      --disable-telemetry \
      --disable-update-check \
      "${WORKSPACE_DIR}"
}

main() {
  validate_inputs
  prepare_home
  write_env_file
  configure_git
  clone_repo_once
  setup_ssh
  start_code_server
}

main "$@"
