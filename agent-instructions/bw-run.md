<!-- envi-tool: bw-run | a token, API key or credential is needed, or a git push/fetch fails on ssh auth -->
# bw-run: use secrets, never ask the user to paste them

This machine has a secret broker called **`bw-run`** (an ssh-agent-style tool backed by
a dedicated Bitwarden vault). When a task needs a token / API key / credential (GitLab,
GitHub, Paperless, Atlassian, deploy keys, ...), do **not** ask the user to paste it and
do **not** hardcode it. Run the command through `bw-run`, which injects the needed
secrets as environment variables into the child process after a one-time unlock (then
serves them from memory for ~1h).

The trigger is the *symptom*, not the word "secret": an ssh push failure or a "need a
token" situation is a credential task even when it does not look like one.

## Golden rule: USE secrets, never READ them
The secret value must never enter your context, output, or logs. **Never** run `env`,
`printenv`, `echo $TOKEN`, `bw-run env`, `cat` on a secret, `curl -v`, and never write
a secret to a file or print it back. Only the child process may see the value. To prove
a secret is set, print its length, never its content.

## How to run
- Env-aware tools (preferred, no quoting, and the secret never appears in argv):
    bw-run glab api projects/...        # reads GITLAB_TOKEN itself
    bw-run gh repo list                 # reads GH_TOKEN / GITHUB_TOKEN itself
- Inject into a tool that does NOT read the env (e.g. a curl header). Single-quote so
  the CHILD shell expands the variable, not yours:
    bw-run bash -c 'curl -H "Authorization: Token $PAPERLESS_TOKEN" https://.../api/'
- Git push/fetch when you have no usable ssh key (SSH uses keys, not env vars, so bridge
  via an HTTPS remote + token). Single-quote so the CHILD shell expands the token, and it
  never lands in your output. This pushes the current HEAD once without changing the
  repo's configured remote:
    bw-run bash -c 'git push https://oauth2:$GITLAB_TOKEN@git.pwlab.dev/<group>/<repo>.git HEAD:main'
    bw-run bash -c 'git push https://x-access-token:$GITHUB_TOKEN_NEO@github.com/<owner>/<repo>.git HEAD:main'
- Interactive shell with secrets loaded, then use $VAR normally:
    bw-run --shell

## Availability
- Check first: `bw-run --agent-status`. If it says "not running", the vault is locked.
- To unlock, just run the `bw-run <cmd>` you need (e.g. `bw-run true`). On a Mac with
  headless Touch ID enabled (`BW_TOUCHID_HEADLESS=true`, see `bw-run --touchid-status`),
  this pops a Touch ID sheet on the Mac: tell the user to tap the sensor, and the unlock
  completes without a new terminal. The sheet auto-dismisses after `BW_TOUCHID_TIMEOUT`s.
- If headless Touch ID is off, or the sheet times out, or you get a "readline was closed"
  style failure (no terminal, so the master-password prompt can't be answered), fall back
  to asking the user to run any `bw-run ...` once to unlock. Never try to supply the
  password, and never put a password on a command line or in the environment.
- `bw-run --stop-agent` wipes the secrets from memory; the agent also auto-expires.

## Which secrets exist
- Run `bw-run-selftest`, it lists each provisioned variable with its length (never the
  value), so you can see what is available without revealing anything.
- The reference list (variable names only, no secret values) lives in
  `~/.envi/integrations/bitwarden/bw-env`.

## More detail
Full documentation: `~/.envi/integrations/bitwarden/README.md`.
