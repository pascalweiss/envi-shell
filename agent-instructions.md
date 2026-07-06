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

## Running commands on remote hosts: use `erun`, not tmux pane scraping

When you need to run a command on a remote host (a server, a k8s node, anything
reachable over ssh), use **`erun`**. Do **not** drive an interactive ssh session by
typing into a tmux pane with `send-keys` + `capture-pane`. Pane scraping has no exit
code, wraps output at the pane width, and mixes in the shell prompt; `erun` gives you
clean stdout/stderr and a real exit code.

### How it works
The user opens an interactive ssh session to the host (in a tmux pane), which is
authenticated however that host needs (key, password, 2FA, jump host). ssh connection
multiplexing (configured in `~/.envi/integrations/ssh/config`) makes that connection
reusable. `erun` runs your command as a new channel over it, so **you need no
credentials of your own** and it works for hosts you have never seen.

### Usage
```
erun --list                    # discover which hosts have an open, reusable session
erun <target> <cmd...>         # run a command, e.g. erun pweiss@10.1.2.3 'kubectl get pods'
```
- `<target>` is what you'd pass to ssh (`user@host`, `host`, or a `Host` alias). It must
  match how the session was opened, so copy the exact string from `erun --list`.
- Quote the remote command so your local shell doesn't expand it:
  `erun forumnode 'df -h /'`.
- `erun` passes the remote exit code through and never prompts for a password. If it says
  the host is not reachable, the user has no open session to it: ask them to run
  `ssh <target>` in a pane first, then retry.

### When pane scraping is still correct
Only for genuinely interactive things: TUIs (`htop`, `k9s`), watching a live process
(`tail -f`, `journalctl -f`), or continuing a REPL/stateful session. For one-shot
commands, always prefer `erun`.
