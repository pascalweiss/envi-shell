# Agent instructions for this machine

Global guidance for any coding agent (Claude Code, Codex, Gemini CLI, OpenCode)
running on this machine. This is the single source of truth: agents are pointed here
by a permanent link injected into their config, so you can edit this file freely and
changes take effect immediately, with no re-provisioning.

## Secrets: use `bw-run`, never ask the user to paste them

This machine has a secret broker called **`bw-run`** (an ssh-agent-style tool backed by
a dedicated Bitwarden vault). When a task needs a token / API key / credential (GitLab,
GitHub, Paperless, Atlassian, deploy keys, …), do **not** ask the user to paste it and
do **not** hardcode it. Run the command through `bw-run`, which injects the needed
secrets as environment variables into the child process after a one-time unlock (then
serves them from memory for ~1h).

### Golden rule: USE secrets, never READ them
The secret value must never enter your context, output, or logs. **Never** run `env`,
`printenv`, `echo $TOKEN`, `bw-run env`, `cat` on a secret, `curl -v`, and never write
a secret to a file or print it back. Only the child process may see the value. To prove
a secret is set, print its length, never its content.

### How to run
- Env-aware tools (preferred, no quoting, and the secret never appears in argv):
    bw-run glab api projects/...        # reads GITLAB_TOKEN itself
    bw-run gh repo list                 # reads GH_TOKEN / GITHUB_TOKEN itself
- Inject into a tool that does NOT read the env (e.g. a curl header). Single-quote so
  the CHILD shell expands the variable, not yours:
    bw-run bash -c 'curl -H "Authorization: Token $PAPERLESS_TOKEN" https://.../api/'
- Interactive shell with secrets loaded, then use $VAR normally:
    bw-run --shell

### Availability
- Check first: `bw-run --agent-status`. If it says "not running", the vault is locked.
- You CANNOT unlock it yourself: it needs the user's master password, typed locally. Ask
  the user to run any `bw-run …` once to unlock; never try to supply the password, and
  never put a password on a command line or in the environment.
- `bw-run --stop-agent` wipes the secrets from memory; the agent also auto-expires.

### Which secrets exist
- Run `bw-run-selftest`, it lists each provisioned variable with its length (never the
  value), so you can see what is available without revealing anything.
- The reference list (variable names only, no secret values) lives in
  `~/.envi/integrations/bitwarden/bw-env`.

### More detail
Full documentation: `~/.envi/integrations/bitwarden/README.md`.
