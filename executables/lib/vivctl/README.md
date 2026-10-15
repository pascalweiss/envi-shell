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
vivctl navigate TAB URL              also: back, forward, reload (reload also loads a hibernated tab)
vivctl click TAB REF [--force]       REF is a number from the last `elements`
vivctl type TAB REF TEXT [--enter]   replaces the text of an element, never a password field
vivctl select TAB REF OPTION         choose an option of a <select> by its text or value
vivctl press TAB KEY                 Enter Tab Escape Backspace Space arrows PageUp PageDown Home End
vivctl scroll TAB up|down|top|bottom
vivctl focus TAB                     make it the active tab
vivctl screenshot TAB                PNG under ~/.vivctl/shots, the path is printed
```

There is no `eval`: the page operations are fixed commands like the rest. What they do and why:

- **Scripts run in an isolated world**, like Playwright's utility world: they share the DOM with
  the page but not its JavaScript, so a page that patches `querySelectorAll`, `JSON` or the
  `value` setter neither breaks them nor sees them.
- **Shadow DOM and iframes.** `elements`, `read`, `click` and `type` reach into open shadow roots
  and same-origin iframes. Cross-origin iframes and closed shadow roots stay out of reach.
- **Finding the page behind a tab.** A tab id cannot be mapped to a DevTools target directly, so
  the candidates are the page targets with the tab's URL. A tab that was restored but never
  loaded has a target without a renderer that never answers; each candidate is probed, and the
  wait ends as soon as as many pages answered as Vivaldi reports loaded tabs with that URL. When
  two loaded tabs show the same page, each gets a marker title for a fraction of a second, and
  the one whose marker appears on the tab is it; the titles are restored right after. A tab that
  is not loaded at all is reported at once, `vivctl reload` loads it.
- **Every input is verified, with a fallback.** Vivaldi drops keyboard input to a tab that is not
  in front, so a key or text could vanish while the command reports success. Instead, the page
  side arms a listener before each real input and checks afterwards whether it arrived. If it
  did not, the same input is produced from the page: text is set as the element's value (which
  frameworks like React register as an edit, since the isolated world bypasses their tracking),
  keys are dispatched as events, and Enter in a form submits it, as the browser would have. The
  result says which path was taken (`via: keyboard`, `mouse` or `script`). Scripted keys are
  untrusted events: the page's handlers see them, but browser defaults such as moving focus with
  Tab or scrolling with PageDown do not happen; `focus` the tab first when that matters.
- **Clicks are aimed.** Before a click, the element is scrolled into view and the point is hit
  tested: if something else is on top (a cookie banner, a modal), the command names it and does
  not click; `--force` clicks the element from the page anyway. The result reports tabs the
  click opened (`newTabs`) and the URL the tab navigated to.
- **Waiting.** After an action the command returns once a navigation it started has finished
  loading, so the next command sees the new page.

A stack is addressed by its title (case-insensitive) or by the first 8 or more characters of
its id. A stack needs two tabs, so a stack is created by `open` with two or more URLs or by
`stack` with two or more tab ids.

Stacks only ever get the tabs that were asked for, and a stack nobody named is never renamed:

- `open` takes its new tabs out of any stack right away. Vivaldi opens a tab next to the active
  one and, when that one is in a stack, puts the new tab into it, so without this a plain
  `open` would grow somebody else's stack, and `open --stack Name` would take over that stack
  and rename it.
- `open --stack Name` joins `Name` if it exists, otherwise it creates a stack of exactly the
  new tabs.
- `stack ID...` makes exactly these tabs one stack. Tabs that sit in another stack leave it,
  and that stack keeps its other tabs, its id, title and color. If the tabs already are exactly
  one stack, that stack is kept and only gets the new title or color. `stack ID... --into Name`
  adds them to `Name` instead.
- Before a title or color is set, the resulting stack is checked to hold exactly the expected
  tabs. If it does not, the command fails and nothing is renamed.

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
| take tabs out of their stack | `tabsPrivate.move({tabIds, target: <index after the last tab>, windowId, tweaks: ["untile","ungroup"]})`, which is what Vivaldi's own "Remove from stack" does; only the moved tabs change |
| read | `vivExtData` of each tab: `group`, `fixedGroupTitle`, `groupColor` |

These are undocumented. A Vivaldi update can change them; the symptom is an operation that
fails or silently does nothing, and the first place to look is `bundle.js` in
`Vivaldi Framework.framework/Resources/vivaldi/`.

Passing `"create-group"` for a tab that is already in a stack makes Vivaldi build a new stack
and tear the old one apart, which is why only the first join carries it, and why a tab is taken
out with `"ungroup"` before it starts a new stack.

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

## No window open

On macOS Vivaldi keeps running when its last window is closed. Its window UI is gone then, but
its background page (`main.html`) stays. `vivctl status` says so, `tabs` and `stacks` answer
with an empty list, and `open` asks the background page to open a window first
(`chrome.windows.create`), so it works as usual. Closing tabs also runs on the background page:
closing the last tab takes the window and its UI page with it, and a call running there would
never return.

## Testing

```bash
executables/lib/vivctl/test/run.sh          # about two minutes, Vivaldi windows appear
executables/lib/vivctl/test/run.sh --keep   # keep the temp directory with profile and logs
```

The suite starts its own daemon on a throwaway profile in a temp directory and serves the pages
in `test/site/` from its own local web server, so it needs no network and never touches a real
profile. It covers stacks (including the cases where the active tab sits in another stack),
every page command in background and front tabs, shadow DOM, iframes, a hostile page that
patches globals, the windowless state, the lock (answered by a script instead of Touch ID) and
tabs that are restored but not loaded. Run it after every Vivaldi update: the calls vivctl
relies on are undocumented, and a changed one shows up there as a failure.

## Files

- `vivctl.mjs`: the daemon and the client, plain Node without dependencies
- `touchid.swift`: the Touch ID check, exit code 0 only if the owner authenticated
- `../../macbin/vivctl`: the wrapper that finds Node (also through nvm) and runs it
- `test/run.sh`, `test/site/`: the live test suite and its pages
- `~/.vivctl/`: socket and `daemon.log`
