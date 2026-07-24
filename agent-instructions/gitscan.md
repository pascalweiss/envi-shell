<!-- envi-tool: gitscan | know which repos have uncommitted, unpushed or never-pushed work -->
# gitscan: find uncommitted / unpushed work across all repos

This machine keeps many git repos and uses git worktrees heavily. When you need to know
what still has to be committed, pushed or pulled (before finishing a task, before a
hand-off, or whenever the user asks "did I forget to commit/push somewhere?"), use
**`gitscan`** instead of manually `cd`-ing around and running `git status`.

`gitscan` discovers every repo under `$HOME` (search is pruned for speed: `node_modules`,
`.gradle`, `target`, `Library`, `.oh-my-zsh`, ... are skipped), classifies each as a
**main** checkout, a linked **worktree**, or **bare**, and reports dirty state plus
ahead/behind vs. the upstream. By default it shows only repos that need attention.

## Usage
```
gitscan                 # only repos needing action (dirty, unpushed, behind, never-pushed)
gitscan --all           # every repo, including clean ones
gitscan ~/dev           # limit to one or more search roots
gitscan --json          # machine-readable array (stable field names), prefer this when parsing
gitscan --fetch         # git fetch first so "behind" counts are current (needs network)
```
- Output auto-adapts: colored table on a TTY, plain text when piped. For programmatic use
  read `--json` (or `--porcelain` for TSV) rather than scraping the table.
- Status tokens: `CHANGES` = `S`taged `M`odified `U`ntracked counts or `clean`; `REMOTE` =
  `↑ahead ↓behind`, `synced`, `no-upstream` (a branch that was never pushed), or `detached`.
- Without `--fetch`, ahead/behind uses the last fetched state of each remote (no network),
  so a `behind` of 0 only means "not behind as of the last fetch".
- Search roots and prune list are configurable via `GITSCAN_ROOTS`, `GITSCAN_MAX_DEPTH`,
  `GITSCAN_PRUNE`, `GITSCAN_JOBS`. A full `$HOME` scan takes a few seconds; narrow it with a
  root argument (e.g. `gitscan ~/dev`) when you only care about one area.

Do **not** commit or push on the user's behalf based on `gitscan` output unless they ask;
its job is to surface what needs attention, the decision stays with the user.
