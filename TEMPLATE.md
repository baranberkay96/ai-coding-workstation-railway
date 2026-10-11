# AI Coding Workstation (Claude Code, Codex, Gemini CLI): Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **AI Coding Workstation (Claude Code, Codex, Gemini CLI)** (LISTINGS.md name, no version label: the workstation bundles several tools and has no single upstream version) |
| Description | Browser VS Code and terminal with AI coding CLIs preinstalled. Persistent home. (79 chars, unchanged) |
| Category | Other |
| Tags | code-server, vscode, claude-code, codex, gemini-cli, opencode, ssh, devbox, ai-coding |

The description is delivered as written: code-server (VS Code in the browser) with its integrated terminal, Claude Code, OpenAI Codex CLI, Gemini CLI and OpenCode preinstalled, and the whole `/home` on a Railway volume. SSH through a TCP proxy is an extra.

## Base market template

- **Base: `ubuntu-ssh-claude`** ("Ubuntu SSH + Claude", 3,850 active / 3,977 recent, the market leader). Kept the concept users choose it for: a Linux box on Railway with root-capable tooling, SSH over a TCP proxy and Claude Code ready to run. Its repo (`parham7991/railway-ubuntu-ssh-claude`) is MIT-licensed, but no file was adapted: our Dockerfile and entrypoint were written from scratch around the official code-server image. Problems fixed: **no volume** (everything is lost on redeploy; it pushes `/root/src` to a GitHub repo as a workaround), root SSH login with a user-chosen password, host keys regenerated on every build, an unpinned `@anthropic-ai/claude-code`, a default `claude-settings.json` that routes Claude Code to a third-party free model via OpenRouter, no browser IDE.
- `code-server` (coder/deploy-code-server, 1,298 active, MIT): browser IDE, but pinned to code-server **4.9.0** (2022), no volume, required `GIT_REPO`, user-chosen password. Idea kept: optional `GIT_REPO` clone on first start.
- `opencode` (LaceLetho/opencode-railway-template, 48 active): OpenCode web UI with a Node proxy and memory monitor. **No license**, read only; nothing copied.
- No README text was reused.

## Pinned versions

| Component | Source | Version | Released | Checked |
|---|---|---|---|---|
| Base image | `codercom/code-server:4.141.0-noble` (official, Ubuntu 24.04 LTS) | 4.141.0 | 2026-10-08 | 2026-10-10 |
| Node.js | NodeSource `setup_24.x` (active LTS "Krypton", 24.21.0 at check time) | 24.x | 2026-09-07 | 2026-10-10 |
| Claude Code | npm `@anthropic-ai/claude-code` (`stable` dist-tag) | 2.1.287 | stable channel | 2026-10-10 |
| OpenAI Codex CLI | npm `@openai/codex` (`latest`) | 0.162.1 | 2026-10-09 | 2026-10-10 |
| Gemini CLI | npm `@google/gemini-cli` (`latest`) | 0.63.0 | stable channel | 2026-10-10 |
| OpenCode | npm `opencode-ai` (`latest`) | 1.18.35 | stable channel | 2026-10-10 |
| uv | Astral installer (`astral.sh/uv/<ver>/install.sh`) | 0.13.0 | 2026-10-09 | 2026-10-10 |
| GitHub CLI | cli.github.com apt repo | latest in repo at build | n/a | 2026-10-10 |

All versions are `ARG`s at the top of `services/workstation/Dockerfile`. Bump an ARG and redeploy to upgrade the image. Users can also upgrade a CLI for themselves without a rebuild: `npm i -g @openai/codex@latest` installs into `~/.npm-global` (on the volume), which comes first in `PATH`.

## Architecture

```
 Browser ── HTTPS (Railway edge) ──► :8080 code-server (VS Code + terminal)   /healthz
 ssh -p <proxy port> coder@<proxy host> ── TCP proxy ──► :2222 sshd (optional)
                                    │
             ┌──────────────────────┴──────────────────────────┐
             │ Workstation (Dockerfile in services/workstation)  │
             │ PID 1 dumb-init → entrypoint (root)                │
             │   ├─ sshd (supervised loop, if enabled)            │
             │   └─ code-server as user "coder" (uid 1000)        │
             │ claude · codex · gemini · opencode · gh · node 24  │
             │ python3 · uv · pipx · build-essential · tmux · rg  │
             │ volume /home  (/home/coder = $HOME, ~/workspace)   │
             └────────────────────────────────────────────────────┘
```

## Services

### Workstation

| Setting | Value |
|---|---|
| Source | repo `baranberkay96/ai-coding-workstation-railway`, root `/services/workstation` (Dockerfile) |
| Healthcheck | `/healthz` (code-server's unauthenticated liveness endpoint), timeout 120 s |
| Public domain | yes, target port 8080 |
| TCP proxy | 2222 (SSH) |
| Volume | `/home` (home of `coder` is `/home/coder`; SSH host keys in `/home/.workstation`, root-only) |
| Restart policy | ON_FAILURE, 10 retries |
| Replicas | 1 (volume-backed, single user) |

Files in `services/workstation/`:
- `Dockerfile`: official code-server image + toolchain + pinned AI CLIs (system-wide, so the `/home` volume never hides them).
- `entrypoint.sh`: seeds `/home/coder` on first boot (non-recursive ownership repair afterwards), writes selected API keys to `/etc/workstation/env.sh` (mode 0640) for SSH sessions, configures git identity and the `gh` credential helper, clones `GIT_REPO` once, starts sshd only when a password or keys are set (host keys persisted on the volume), then hashes `PASSWORD` with argon2 and runs code-server as `coder` with `PASSWORD`/`SSH_PASSWORD` removed from its environment.
- `workstation-profile.sh`: PATH (`~/.local/bin`, `~/.npm-global/bin` first), `NPM_CONFIG_PREFIX`, env file sourcing, SSH login banner.
- `tmux.conf`, `motd.txt`.

Variables (descriptions in `template.json`):

| Variable | Default | Notes |
|---|---|---|
| `PASSWORD` | `${{secret(24)}}` | Browser IDE login. Passed to code-server only as an argon2 hash. |
| `PORT` | `8080` | code-server port. |
| `SSH_PASSWORD` | `${{secret(32)}}` | Password SSH for `coder`. Empty = key-only. |
| `SSH_AUTHORIZED_KEYS` | empty | Public keys, one per line. |
| `SSH_PORT` | `2222` | TCP proxy target. |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY` | empty | All optional: every CLI also supports subscription/OAuth login from the terminal. |
| `GITHUB_TOKEN`, `GIT_USER_NAME`, `GIT_USER_EMAIL`, `GIT_REPO` | empty | Optional git setup. |
| `WORKSTATION_ENV_PASSTHROUGH` | empty | Extra variable names to expose in SSH sessions. |
| `TZ` | `UTC` | Time zone. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `15` | Clean shutdown on redeploy. |

No required inputs: the template boots with generated passwords, and users log in to each CLI with their own subscription or key.

## First login

1. Open the public URL, enter `PASSWORD` (Variables tab).
2. Open a terminal (Ctrl+`) and run `tmux new -A -s main` so agents keep running when the tab closes.
3. Log in to the CLIs you use: `claude`, `codex login --device-auth`, `NO_BROWSER=true gemini`, `opencode auth login`, or set the matching API key variables.
4. SSH (optional): Railway → service → Settings → Networking shows the TCP proxy host and port. Run `ssh -p <port> coder@<host>` with `SSH_PASSWORD`, or add your public key to `SSH_AUTHORIZED_KEYS` and clear `SSH_PASSWORD` for key-only access.

## Improvements over market templates

1. **Persistent home on a volume** (`/home`): projects, CLI logins (`~/.claude`, `~/.codex`, `~/.gemini`, `~/.config/opencode`), VS Code extensions and settings survive redeploys. The market leader loses everything on redeploy.
2. **Browser IDE and SSH in one service**: code-server plus optional sshd through a TCP proxy, instead of SSH-only or IDE-only.
3. **Four AI CLIs, pinned, from official packages**, installed system-wide; per-user upgrades on the volume take precedence without a rebuild.
4. **No third-party model routing**: CLIs talk to their own vendors unless the user configures otherwise.
5. **Safer access**: generated passwords, no root SSH login, `AllowUsers coder`, host keys persisted (no "host key changed" warnings after redeploys), IDE password kept out of the terminal environment, key-only SSH supported.
6. **Current code-server** (4.141.0 vs 4.9.0) with telemetry and update checks off.
7. **Healthcheck** on `/healthz`; dumb-init as PID 1 reaps orphaned agent subprocesses.

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month.

| Service | Idle RAM / CPU | Typical RAM / CPU | Notes |
|---|---|---|---|
| Workstation | 0.3 GB / 0.02 vCPU | 1.5 GB avg, 3-4 GB peaks / 0.3 vCPU avg | Peaks from builds, language servers and 2-3 agent CLIs running in parallel |
| Volume `/home` | 1 GB | 5-10 GB | node_modules, virtualenvs, git checkouts |

Estimated monthly cost: **idle ≈ $4**, **typical ≈ $22** (1.5 GB × $10 + 0.3 vCPU × $20 + 10 GB × $0.15). AI usage is billed by the respective vendor.

Minimum plan: **Hobby**. Trial (1 GB per service) runs the IDE and one CLI but builds will run out of memory. Hobby's 5 GB volume limit is tight for several Node projects; Pro allows larger volumes.

## Verification checklist

- [ ] Build completes; the last Dockerfile step prints versions for `claude`, `codex`, `gemini`, `opencode`.
- [ ] `GET /healthz` returns 200; the IDE asks for a password and accepts `PASSWORD`.
- [ ] In the browser terminal: `echo $PASSWORD` is empty; `claude --version`, `codex --version`, `gemini --version`, `opencode --version`, `node -v` (v24), `uv --version`, `gh --version` all work.
- [ ] `claude` login flow completes in the terminal (or `ANTHROPIC_API_KEY` is picked up).
- [ ] SSH: `ssh -p <proxy port> coder@<proxy host>` works with `SSH_PASSWORD`; with `SSH_PASSWORD` cleared and a key set, password login is refused and key login works.
- [ ] Persistence: create `~/workspace/test.txt`, install an extension, log in to a CLI, redeploy. All three survive, and the SSH host key fingerprint is unchanged.
- [ ] `npm i -g @openai/codex@latest` as `coder` installs into `~/.npm-global` and `which codex` points there.

## Open questions

- Railway's handling of a public HTTP domain and a TCP proxy on the same service is assumed from the market leader (TCP proxy only) and the code-server template (HTTP only). Both are standard Railway features, but the combination was not deploy-tested.
- `sudo` works inside the container (code-server image default), but system packages installed with apt are lost on redeploy. Only `/home` persists, which is documented in the login banner.
- Codex CLI's Linux sandbox (Landlock/seccomp) and Claude Code's bubblewrap sandbox may be restricted by Railway's container runtime; if so, users run the CLIs without their sandbox (the container itself is the isolation boundary).
- The Hobby plan's 5 GB volume cap is assumed from STANDARD.md and may change.
- Claude Code's background auto-updater on an npm install that lives in a root-owned prefix: Anthropic documents a one-time notice when the global npm directory is not writable. Whether the updater instead honours `NPM_CONFIG_PREFIX=~/.npm-global` (and so updates itself onto the volume) needs to be confirmed on a first deploy. Manual `npm i -g @anthropic-ai/claude-code@latest` works either way.
