# Deploy and Host AI Coding Workstation with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ai-coding-workstation-claude-code-codex-)

A cloud development box with VS Code in the browser (code-server), a full terminal and optional SSH. Claude Code, OpenAI Codex CLI, Gemini CLI and OpenCode come preinstalled, along with Node.js, Python, uv, git, gh and build tools. Your home directory, projects and CLI logins live on a persistent volume.

## About Hosting AI Coding Workstation

AI coding agents work best on a machine that stays online: long tasks keep running after you close your laptop, and you can check in from any browser or phone. Hosting one yourself means maintaining a Linux box with an IDE, the agent CLIs, language runtimes, secure remote access and storage that survives rebuilds. This template builds on the official code-server image (Ubuntu 24.04 LTS), installs each AI CLI from its vendor's official npm package at a pinned version, mounts a Railway volume at `/home`, protects the IDE with a generated password and offers SSH through a Railway TCP proxy. You bring your own subscriptions or API keys.

## Common Use Cases

- Run Claude Code, Codex, Gemini CLI or OpenCode on long refactors and keep them going in `tmux` while you are offline
- A consistent dev environment you can open from any device, including tablets and locked-down work laptops
- Remote pair programming or demos without sharing your local machine
- Trying several AI coding agents side by side on the same repository

## Dependencies for AI Coding Workstation Hosting

- A Railway volume for `/home` (included)
- Optional: accounts or API keys for the AI tools you use (Claude Pro/Max or Anthropic API, ChatGPT or OpenAI API, Google account or Gemini API key, any OpenCode provider)
- Optional: a GitHub token for private repositories

### Deployment Dependencies

- code-server: https://github.com/coder/code-server
- Claude Code setup: https://code.claude.com/docs/en/setup
- OpenAI Codex CLI: https://github.com/openai/codex
- Gemini CLI: https://github.com/google-gemini/gemini-cli
- OpenCode: https://opencode.ai
- Railway TCP proxy: https://docs.railway.com/networking/tcp-proxy

### Implementation Details

| Service | Source | Purpose |
|---|---|---|
| Workstation | Dockerfile based on `codercom/code-server:4.141.0-noble` | Browser IDE on port 8080, optional sshd on 2222 (TCP proxy), AI CLIs, volume at `/home` |

**First login**

1. Open the service URL and enter the value of `PASSWORD` from the service's Variables tab.
2. Open a terminal and start a persistent session: `tmux new -A -s main`.
3. Sign in to your tools: `claude`, `codex login --device-auth`, `NO_BROWSER=true gemini`, `opencode auth login`, or set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY` as variables.
4. For SSH, copy the TCP proxy host and port from Settings → Networking and run `ssh -p {port} coder@{host}` with `SSH_PASSWORD`. For key-only access, put your public key in `SSH_AUTHORIZED_KEYS` and clear `SSH_PASSWORD`.

**What persists**: everything under `/home/coder` (projects in `~/workspace`, CLI logins, VS Code extensions and settings, per-user npm and pip installs). System packages installed with `sudo apt` reset on redeploy.

**Scaling**: this is a single-user machine, so keep one replica. Railway scales the service's RAM and CPU vertically up to your plan limit, which covers parallel agents and builds. For a team, deploy one workstation per person.

**Pinning and upgrades**: code-server, Node.js and each CLI version are build arguments at the top of the Dockerfile. Change them and redeploy. To get a newer CLI immediately without a rebuild, run `npm i -g {package}@latest` as `coder`; it installs into `~/.npm-global` on the volume, which comes first in `PATH`.

### Why Deploy AI Coding Workstation on Railway?

Railway gives the workstation a stable HTTPS URL, a TCP proxy for SSH and a persistent volume with no server administration. It keeps your agents running while you are away, and you pay for the CPU and memory the box actually uses.
