# NOTICE: AI Coding Workstation template

## Software installed in the image

| Component | Source | License | How it is used |
|---|---|---|---|
| code-server | `codercom/code-server:4.141.0-noble`, https://github.com/coder/code-server | MIT, Copyright (c) 2019 Coder Technologies Inc. | Base image (`FROM`), unmodified binaries |
| Ubuntu 24.04 LTS | via the code-server `noble` image | various (Debian/Ubuntu packages) | Base OS and apt packages |
| Node.js 24 LTS | NodeSource apt repository | MIT (Node.js) | Runtime for the CLIs |
| Claude Code | npm `@anthropic-ai/claude-code@2.1.287` | Proprietary (Anthropic Commercial Terms of Service) | Installed unmodified from Anthropic's official npm package; use is subject to Anthropic's terms |
| OpenAI Codex CLI | npm `@openai/codex@0.162.1`, https://github.com/openai/codex | Apache-2.0 | Installed unmodified |
| Gemini CLI | npm `@google/gemini-cli@0.63.0`, https://github.com/google-gemini/gemini-cli | Apache-2.0 | Installed unmodified |
| OpenCode | npm `opencode-ai@1.18.35`, https://github.com/anomalyco/opencode | MIT | Installed unmodified |
| uv | Astral installer 0.13.0, https://github.com/astral-sh/uv | MIT or Apache-2.0 | Installed unmodified |
| GitHub CLI | cli.github.com apt repository | MIT | Installed unmodified |

Product names belong to their owners. This is a community template, not affiliated with Coder, Anthropic, OpenAI, Google or the OpenCode project. Users supply their own accounts and keys and are bound by each vendor's terms.

## Upstream files and docs checked (2026-10-10)

- `coder/code-server` tag `v4.141.0`: `ci/release-image/Dockerfile` (user `coder`, dumb-init, fixuid, port 8080), `ci/release-image/entrypoint.sh`, `ci/release-image/docker-bake.hcl` (`noble` = Ubuntu 24.04 tag)
- Claude Code install docs: https://code.claude.com/docs/en/setup (native installer, apt/dnf/apk repos, npm package; npm package requires Node.js 22+)
- OpenCode README (install methods incl. `npm i -g opencode-ai`), Codex CLI `codex login --device-auth`, Gemini CLI `NO_BROWSER`
- npm dist-tags for all four CLIs; NodeSource `setup_24.x`; Node.js release index (24.x = active LTS)

## Market templates and repositories reviewed

| Template / repo | License | Use |
|---|---|---|
| `ubuntu-ssh-claude` / `parham7991/railway-ubuntu-ssh-claude` | MIT, Copyright (c) 2025 Egor | Reviewed for feature expectations (SSH via TCP proxy, Claude Code preinstalled, tmux helper). No files adapted. |
| `code-server` / `coder/deploy-code-server` | MIT, Copyright (c) 2016 Trung Tran | Reviewed (optional `GIT_REPO` clone idea). No files adapted. |
| `opencode` / `LaceLetho/opencode-railway-template` | none (all rights reserved) | Read only, nothing copied. |

All files in this package (Dockerfile, entrypoint.sh, workstation-profile.sh, tmux.conf, motd.txt and the docs) were written for this template.
