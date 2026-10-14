---
name: vivctl
description: >-
  Use when a task is about the user's Vivaldi browser: organise or clean up tabs, open
  a set of pages as a named, colored tab stack, add a tab to a stack, rename, recolor,
  dissolve or close a stack, or list what is open. `vivctl` drives Vivaldi through a
  private control daemon with a fixed set of operations. macOS only.
metadata:
  envi: "true"
---

# vivctl: tab and tab stack control for Vivaldi

Use **`vivctl`** for any tab or tab stack work in Vivaldi. Do not drive the browser with
screenshots or keyboard simulation, and do not start Vivaldi with a debug port: `vivctl`
exists so that nothing has raw access to the browser.

## First

```
vivctl status        # is the daemon up, and is it unlocked?
vivctl start         # if not: starts Vivaldi under the daemon
```

If `status` says the daemon is not running, start it; if `start` times out, read
`~/.vivctl/daemon.log`. A Vivaldi that was opened normally has no control channel. Tell the
user, and do not close it yourself: it holds their tabs.

**The daemon is locked until the user has used Touch ID.** Every command except `status`,
`unlock` and `lock` fails with "locked" until then. When you see that, run `vivctl unlock`:
a Touch ID sheet opens on the Mac, tell the user to tap the sensor, and access then lasts an
hour. If the unlock fails or times out, stop and say so; never work around the lock (no
`VIVCTL_AUTH=off`, no second daemon, no raw access to the browser). The lock is the user's
consent for you to touch their browser.

## Commands

```
vivctl unlock | lock                             Touch ID, opens the commands below for an hour
vivctl tabs [--json]                             id, stack, title, url of every tab
vivctl stacks [--json]                           stack id, color, title, tab ids
vivctl open URL... [--stack NAME] [--color C] [--focus]
vivctl stack TABID... [--into STACK] [--title T] [--color C]
vivctl title STACK TITLE
vivctl color STACK COLOR        # grey blue red yellow green pink purple teal orange
vivctl unstack STACK            # dissolve, tabs stay open
vivctl close-stack STACK        # closes the tabs too
vivctl close TABID...
vivctl stop                     # quits Vivaldi
```

STACK is a title (case-insensitive) or the first 8 or more characters of the stack id.

## Rules of thumb

- A stack needs two tabs. `open A B --stack Name` creates it; `open C --stack Name` joins it
  afterwards; `open C --stack Missing` with one URL fails on purpose.
- `close-stack`, `close` and `stop` throw away open pages. Run `vivctl stacks` or `tabs`
  first, name what you are about to close, and do it only when the user asked for exactly
  that. `unstack` is the harmless way to get rid of a stack.
- `tabs` lists the user's real titles and URLs. Filter before quoting (`--json` and a
  query) and keep private pages out of tickets and commit messages.
- `tabs` shows URLs without query and fragment (`?...`, `#...`). That is deliberate and not a
  bug to work around.
- Use `--json` when you parse the output.

Design, threat model and the Vivaldi calls underneath are in
`~/.envi/executables/lib/vivctl/README.md`.
