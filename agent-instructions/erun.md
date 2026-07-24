<!-- envi-tool: erun | run a command on a remote host (server, k8s node) over an existing ssh session -->
# erun: run commands on remote hosts, not tmux pane scraping

When you need to run a command on a remote host (a server, a k8s node, anything
reachable over ssh), use **`erun`**. Do **not** drive an interactive ssh session by
typing into a tmux pane with `send-keys` + `capture-pane`. Pane scraping has no exit
code, wraps output at the pane width, and mixes in the shell prompt; `erun` gives you
clean stdout/stderr and a real exit code.

## How it works
The user opens an interactive ssh session to the host (in a tmux pane), which is
authenticated however that host needs (key, password, 2FA, jump host). ssh connection
multiplexing (configured in `~/.envi/integrations/ssh/config`) makes that connection
reusable. `erun` runs your command as a new channel over it, so **you need no
credentials of your own** and it works for hosts you have never seen.

## Usage
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

## When pane scraping is still correct
Only for genuinely interactive things: TUIs (`htop`, `k9s`), watching a live process
(`tail -f`, `journalctl -f`), or continuing a REPL/stateful session. For one-shot
commands, always prefer `erun`.
