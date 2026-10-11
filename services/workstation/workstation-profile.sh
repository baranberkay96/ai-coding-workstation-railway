# AI Coding Workstation shell environment.
# Sourced by login shells (/etc/profile.d) and interactive shells (/etc/bash.bashrc).

# Per-user installs on the persistent volume take precedence over the image's
# system-wide tools, so `npm i -g <cli>@latest` or a native installer in
# ~/.local/bin upgrades a CLI without rebuilding the image.
case ":${PATH}:" in
  *":${HOME}/.npm-global/bin:"*) ;;
  *) PATH="${HOME}/.local/bin:${HOME}/.npm-global/bin:${PATH}" ;;
esac
export PATH
export NPM_CONFIG_PREFIX="${HOME}/.npm-global"
export EDITOR="${EDITOR:-nano}"

# API keys and git identity from Railway variables (written at container start).
if [ -r /etc/workstation/env.sh ]; then
  . /etc/workstation/env.sh
fi

# Short tool overview on interactive SSH logins.
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${WORKSTATION_MOTD_SHOWN:-}" ] && [ -t 1 ] && [ -r /etc/workstation/motd.txt ]; then
  cat /etc/workstation/motd.txt
  export WORKSTATION_MOTD_SHOWN=1
fi
