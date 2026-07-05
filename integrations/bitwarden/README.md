# Bitwarden Secret Agent (`bw-run`)

An ssh-agent-style broker for a dedicated, AI-only Bitwarden vault. Unlock once
with your master password, then scripts and AI tools read the listed secrets
from an in-memory daemon (Unix socket, TTL) without re-authenticating. Secrets
are never written to disk.

Cross-platform by design: the unlock is `bw unlock` (master password on the CLI),
identical on macOS and headless Linux, no biometrics, no platform-specific code.

## Files
| File | Purpose |
|------|---------|
| `with-secrets.sh` | Wrapper behind the `bw-run` command: unlock + resolve + inject env |
| `secret-agent.py` | Background daemon holding secrets in memory (backend-agnostic) |
| `bw-env.example`  | Copy to `bw-env`, list your secret references (no secrets) |
| `init.sh` | Exposes the `bw-run` command; defaults `BW_SECRET_AGENT_TTL` |

## One-time setup (per machine)
```bash
# Tooling: bw + python3 (+ jq for field: references)
brew install bitwarden-cli jq          # macOS
# apt install jq  &&  install bw CLI    # Linux

bw login <ai-account-email>            # log the CLI into the DEDICATED AI account
cp integrations/bitwarden/bw-env.example integrations/bitwarden/bw-env
$EDITOR integrations/bitwarden/bw-env  # match your AI-vault item names
exec zsh                               # pick up the `bw-run` command
```

## Use
```bash
bw-run <command> [args...]   # first run: prompts master password once
bw-run --shell               # open a shell with secrets loaded (use $VAR directly)
bw-run --agent-status
bw-run --stop-agent          # wipe secrets from memory now
```

### Usage patterns (cleanest first)
```bash
# 1. Tools that read their token from the env, no wrapping, no quoting.
#    (Also safest: the secret never appears in the process argv.)
bw-run glab api projects/...        # reads GITLAB_TOKEN
bw-run gh repo list                 # reads GH_TOKEN / GITHUB_TOKEN

# 2. Interactive: open a shell once, then use $VAR normally.
bw-run --shell
#   inside: curl -H "Authorization: Token $PAPERLESS_TOKEN" https://.../api/...

# 3. One-off injection into a tool that does NOT read the env (e.g. a curl
#    header). Single-quote so the CHILD shell expands $VAR, not your shell:
bw-run bash -c 'curl -H "Authorization: Token $PAPERLESS_TOKEN" https://.../api/'
```
Never print the value: avoid `env`, `echo $VAR`, `curl -v`.
- TTL: `BW_SECRET_AGENT_TTL` seconds (default 3600). Per-machine override in `config/envi_env`.
- Disable entirely: `BW_SECRETS_ENABLED=false`.
- Socket/PID live in `$XDG_RUNTIME_DIR` (Linux) or `$TMPDIR` (macOS), never secrets.

## Teaching coding agents about `bw-run`
So that every coding agent on a machine knows to use `bw-run` (instead of asking you
to paste secrets), point them at the single instruction file with `envi-agent-notes`.
It injects only a **link** (a short managed block between HTML-comment markers) into
each *installed* agent's global instruction file, Claude Code `~/.claude/CLAUDE.md`,
Codex `~/.codex/AGENTS.md`, Gemini `~/.gemini/GEMINI.md`, OpenCode
`~/.config/opencode/AGENTS.md`. Agents whose config dir is absent are skipped.

```bash
envi-agent-notes             # inject / update the link (idempotent)
envi-agent-notes --dry-run   # preview, write nothing
envi-agent-notes --uninstall # remove the block everywhere
```

Only a link to `~/.envi/agent-instructions.md` is injected, never the prose. So you
edit that one file whenever you like and the change is live immediately, no
re-injection. Re-run `envi-agent-notes` only when adding a brand-new agent/machine.

## Trust model
While the agent runs, any process under your UID can read the secrets from the
socket (same as ssh-agent/gpg-agent/op). The dedicated AI-only account bounds the
blast radius: the bw session key can only ever decrypt AI secrets.

## The bw single-account caveat
The bw CLI is single-account. Keep it logged into the AI account only; use the
desktop app/browser for your main vault.

## Servers (Forum 0 / Forum 1)
Same flow: SSH in, `bw-run <cmd>`, type the master password once per TTL.
Note: this assumes an interactive session to type the password. Fully unattended
cron jobs have no human to unlock, that case would need `bw`'s `--passwordfile`
/ `BW_PASSWORD`, which reintroduces a secret at rest, so it is intentionally not
wired here.
