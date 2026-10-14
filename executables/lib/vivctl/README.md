# vivctl

Manage Vivaldi tabs and tab stacks from the command line, so that scripts and coding
agents can organise a browser without anybody clicking.

```
vivctl init                                   once per Mac: create the profile the daemon runs
vivctl start                                  run Vivaldi under the control daemon (locked)
vivctl unlock | lock                          Touch ID opens everything below for 60 minutes
vivctl open https://a.example https://b.example --stack Research --color blue
vivctl open https://c.example --stack research     add a tab to an existing stack
vivctl stacks                                 list stacks (id, color, title, tab ids)
vivctl title research "Research 2"            rename
vivctl color research green                   grey blue red yellow green pink purple teal orange
vivctl unstack research                       dissolve, keep the tabs
vivctl close-stack research                   close the stack and all its tabs
vivctl tabs [--json]                          every tab with its stack, query and fragment of URLs cut off
vivctl stop                                   close Vivaldi
```

Pages, like Playwright but through the same daemon (tab ids from `tabs` or `open`):

```
vivctl read TAB [--max N]            title, url and visible text, default 20000 characters
vivctl elements TAB                  clickable and editable elements, numbered
vivctl navigate TAB URL              also: back, forward, reload
vivctl click TAB REF                 REF is a number from the last `elements`
vivctl type TAB REF TEXT [--enter]   replaces the text of an element, never a password field
vivctl press TAB KEY                 Enter Tab Escape Backspace Space arrows PageUp PageDown Home End
vivctl focus TAB                     make it the active tab
vivctl screenshot TAB                PNG under ~/.vivctl/shots, the path is printed
```

There is no `eval`: the page operations are fixed commands like the rest. A tab id cannot be
mapped to a DevTools target directly, so the page is found by URL and title. Tabs that were
restored but never loaded have no page and are skipped. If two loaded tabs show the same page,
or none does, the command fails and says so instead of guessing. In a tab that is not visible
the browser takes no real keyboard input, so `type` sets the value in the page and then checks
that it arrived; `press` and `type --enter` ask for `vivctl focus` first.

A stack is addressed by its title (case-insensitive) or by the first 8 or more characters of
its id. A stack needs two tabs, so a stack is created by `open` with two or more URLs or by
`stack` with two or more tab ids.

## How it works

Vivaldi's tab stacks live in the browser's own UI, which is a web page
(`window.html`) with private extension APIs (`vivaldi.tabsPrivate.*`). They are not part of
the Chrome Extensions API, so the only way in from outside is the Chrome DevTools Protocol.

`vivctl start` spawns a small daemon. The daemon starts Vivaldi with
`--remote-debugging-pipe`, attaches to the UI page over that pipe, and serves a fixed set of
operations on a unix socket. Every other `vivctl` command is a client of that socket.

Verified against Vivaldi 8.2 (Chromium 152). The calls it relies on:

| Purpose | Call |
|---|---|
| create a stack, add a tab | `tabsPrivate.move({tabIds, target: <ext_id of a tab>, tweaks: ["target-is-tab","do-not-reparent","on"]})`, plus `"create-group"` for the first join only |
| title, color | `tabsPrivate.setGroupProperties({groupExtId, groupTitle, groupColor})`, colors are `color1` to `color9` |
| dissolve | `tabsPrivate.unstack(groupId)` |
| read | `vivExtData` of each tab: `group`, `fixedGroupTitle`, `groupColor` |

These are undocumented. A Vivaldi update can change them; the symptom is an operation that
fails or silently does nothing, and the first place to look is `bundle.js` in
`Vivaldi Framework.framework/Resources/vivaldi/`.

Passing `"create-group"` for a tab that is already in a stack makes Vivaldi build a new stack
and tear the old one apart, which is why only the first join carries it.

## The profile

Chromium ignores `--remote-debugging-*` when the profile is its default directory, so the
daemon needs a profile of its own. `VIVCTL_PROFILE` points at it, default
`~/Library/Application Support/Vivaldi-Ctl`.

Once per Mac, with Vivaldi quit:

```bash
vivctl init
```

It copies Vivaldi's own profile (`VIVCTL_SOURCE_PROFILE`, default
`~/Library/Application Support/Vivaldi`) without its caches, then removes the sync identity
from the copy (the `sync` block in `Default/Preferences` and the `Sync Data` directory).
Otherwise the copy would be the same sync device as the original and its changes would flow
back. It refuses to run while Vivaldi has the source profile open, and it never overwrites an
existing `Vivaldi-Ctl`.

Do not carry a profile from one Mac to another instead: cookies and saved passwords are
encrypted with the "Vivaldi Safe Storage" key of that Mac's keychain, so the copy would open
logged out and without readable passwords. Run `vivctl init` on each Mac.

The copy is a snapshot and does not follow later changes in the original.

## Threat model

An open DevTools interface gives whoever can reach it full control of the browser: every page,
every logged-in session, every cookie. That is why this tool does not use the usual
`--remote-debugging-port`:

- **No network port.** The pipe is two inherited file descriptors. Only the daemon, which
  spawned Vivaldi, holds them. No other local process and no web page can connect.
- **A whitelist, not CDP.** The socket accepts a closed set of operations. Caller input
  reaches Vivaldi only as JSON parameters to fixed code, never as code. Tab ids must be
  integers, stack ids UUIDs, colors come from a fixed list, and URLs must be `http` or
  `https`, so `javascript:` and `chrome:` are refused. An agent using `vivctl` cannot read
  cookies, run scripts or reach other processes. It can read the visible text of pages,
  navigate, click and type (see below).
- **Socket permissions.** `~/.vivctl` is `0700` and the socket `0600`, so only your own user
  reaches it.
- **A lock with a lease.** The daemon starts locked. Until `vivctl unlock` has passed a Touch ID
  check (password as the fallback on a Mac without the sensor), it answers only `status`,
  `unlock` and `lock`, so neither a script nor an agent can touch the browser unnoticed: the
  sheet is the consent. A pass opens the daemon for `VIVCTL_LEASE_MINUTES` (default 60) and it
  locks again by itself. The check is run by the daemon, which spawns `touchid.swift`
  (compiled on first use, cached by checksum like `docscan`), so a client cannot claim a
  success it did not get. `VIVCTL_AUTH=off` removes the lock; a daemon without the helper
  refuses to start rather than run unlocked.
- **URLs without secrets.** `tabs` returns the origin and path only; a query or fragment shows
  as `?...` and `#...`. Magic links and reset tokens usually live there. A token in the path
  (`/reset/<token>`) and a revealing page title are not caught.

**Pages are the largest exposure.** `read` and `screenshot` put the content of any open tab,
logged-in ones included, into whoever called them, and with `navigate`, `click` and `type` an
agent can act in your sessions. The consequences:

- Page text is untrusted data. A page can contain instructions aimed at the agent, and an agent
  that reads it while it can also navigate and type is the target of such an attack. Nothing in
  the tool can tell an instruction from content; the agent skill says so, and that is all there is.
- Personal data in a tab (banking, payslips) ends up in the transcript if it is read.
  `VIVCTL_DENY` takes a comma separated list of host suffixes (`bank.example,example.org`)
  whose pages the page commands refuse and `navigate` will not open. It is empty by default.
- `type` refuses password fields on purpose, so that a secret never has to pass through the model.
- Everything is behind the Touch ID lock, and the lease is the window in which all of this works.

What remains: while unlocked, `vivctl tabs` returns titles and URL paths of everything open and
any process running as you can call the socket. The lock lives inside the daemon, so a process
that attaches a debugger to the daemon gets past it and holds the pipe, which is full browser
control. Nothing here defends against an attacker who already runs as you. A Vivaldi that was not started by `vivctl start` has no
pipe and cannot be controlled; start it with `vivctl start` instead. Vivaldi launched a
second time on the same profile hands over to the running instance and exits, which leaves a
daemon without a browser (see `~/.vivctl/daemon.log`).

## Files

- `vivctl.mjs`: the daemon and the client, plain Node without dependencies
- `touchid.swift`: the Touch ID check, exit code 0 only if the owner authenticated
- `../../macbin/vivctl`: the wrapper that finds Node (also through nvm) and runs it
- `~/.vivctl/`: socket and `daemon.log`
