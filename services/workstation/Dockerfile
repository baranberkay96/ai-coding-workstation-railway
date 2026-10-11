# syntax=docker/dockerfile:1
#
# AI Coding Workstation for Railway
# Browser VS Code (code-server) + terminal + optional SSH, with AI coding CLIs
# preinstalled. Users bring their own API keys / subscriptions.
#
# Base: official code-server image on Ubuntu 24.04 LTS ("noble" variant).
ARG CODE_SERVER_VERSION=4.141.0
FROM codercom/code-server:${CODE_SERVER_VERSION}-noble

# Pinned tool versions (bump deliberately; see TEMPLATE.md "Pinned versions").
ARG NODE_MAJOR=24
ARG CLAUDE_CODE_VERSION=2.1.287
ARG CODEX_VERSION=0.162.1
ARG GEMINI_CLI_VERSION=0.63.0
ARG OPENCODE_VERSION=1.18.35
ARG UV_VERSION=0.13.0

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Base toolchain. The code-server image already ships curl, git, git-lfs,
# htop, nano, vim-tiny, wget, zsh, sudo, openssh-client and dumb-init.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential pkg-config ca-certificates gnupg \
      python3 python3-dev python3-pip python3-venv pipx \
      tmux openssh-server argon2 \
      ripgrep fd-find jq unzip zip xz-utils less tree file rsync \
      iputils-ping dnsutils bubblewrap socat tzdata \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# Node.js LTS from NodeSource (needed by Gemini CLI; Claude Code's npm
# package requires Node 22+).
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version && npm --version

# GitHub CLI from GitHub's official apt repository.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# uv (Python package/project manager) via Astral's official installer.
RUN curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
 && uv --version

# AI coding CLIs via their official npm packages, installed system-wide so the
# persistent /home volume does not hide them. Users can still upgrade per user:
# NPM_CONFIG_PREFIX points at ~/.npm-global (on the volume), which comes first
# in PATH (see workstation-profile.sh).
RUN npm install -g --omit=dev \
      "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "@openai/codex@${CODEX_VERSION}" \
      "@google/gemini-cli@${GEMINI_CLI_VERSION}" \
      "opencode-ai@${OPENCODE_VERSION}" \
 && npm cache clean --force \
 && claude --version && codex --version && gemini --version && opencode --version

# Workstation wiring: entrypoint, shell profile, tmux defaults.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/workstation-entrypoint
COPY --chmod=0644 workstation-profile.sh /etc/profile.d/workstation.sh
COPY --chmod=0644 tmux.conf /etc/tmux.conf
COPY --chmod=0644 motd.txt /etc/workstation/motd.txt
RUN echo '[ -r /etc/profile.d/workstation.sh ] && . /etc/profile.d/workstation.sh' >> /etc/bash.bashrc \
 && mkdir -p /run/sshd /etc/ssh/authorized_keys.d \
 && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

ENV PORT=8080 \
    SHELL=/bin/bash \
    GEMINI_SANDBOX=false

EXPOSE 8080 2222

# dumb-init (from the code-server image) is PID 1: it reaps orphaned processes
# spawned by agents and forwards signals. The entrypoint runs as root to fix
# volume ownership and start sshd, then drops to the "coder" user.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/workstation-entrypoint"]
CMD []
