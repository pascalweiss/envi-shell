---
name: repo-cleanup
description: >-
  Triage uncommitted, untracked and unpushed work across every git repo on this
  machine, one repo at a time, with the user deciding what to keep. Use when the
  user wants to clean up or review scattered changes ("go through my repos", "what
  did I forget to commit", "help me tidy up my working copies").
# --- envi skill metadata (ignored by Claude, read by the envi installer) ---
when: the user wants to review and clean up scattered uncommitted work across repos
uses: [gitscan]
agents: all
invocable: true
---

# Repo cleanup: triage scattered work, human in the loop

Go through every repo that has pending work and help the user decide, per repo,
what to keep. You do the analysis and recommend; the user decides. You never
discard, commit, or push anything without an explicit yes for that specific item.

## Ground rules (read first)

- **Never destroy work without explicit confirmation.** `git checkout -- .`,
  `git reset --hard`, `git clean`, `git stash drop`, deleting a branch: each of these
  needs a clear, per-repo "yes, discard this" from the user. When unsure, keep.
- **Never commit or push on the user's behalf** unless they say so for that repo.
- Work **one repo at a time**. Do not dump all repos at once; the user cannot review
  a wall of diffs. Show one, get a decision, move on.
- You are a recommender. State your recommendation and your confidence, then ask.

## Step 1: get the list of repos needing attention

Run the envi tool `gitscan` (see the `gitscan` skill) in JSON mode:

```
gitscan --json
```

Each entry has `path`, `type` (main/worktree/bare), `branch`, `staged`, `modified`,
`untracked`, `ahead`, `behind`, `upstream`, `stash`. Keep only entries where there is
something to triage: `staged+modified+untracked > 0`, or `ahead > 0`, or a real branch
with `upstream == "-"` (never pushed). Group worktrees under their `main` so related
checkouts are reviewed together.

Tell the user up front how many repos need attention and give a one-line overview
(e.g. "12 repos: 8 with uncommitted changes, 3 with unpushed commits, 4 never pushed").

## Step 2: for each repo, analyze before you ask

For the current repo, gather the facts (do not modify anything):

```
git -C <path> status --short
git -C <path> diff --stat            # scope of unstaged changes
git -C <path> diff --stat --cached   # scope of staged changes
git -C <path> log --oneline @{upstream}..HEAD   # unpushed commits, if upstream exists
```

Read enough of the actual diff to judge intent, not just the file list. Look for
signals that separate throwaway from valuable:

- **Likely throwaway:** debug prints, commented-out code, `.log`/`.tmp`/build output,
  editor scratch files, a single reverted-looking change, `TODO test` stubs, formatting
  churn only, accidental large binaries.
- **Likely valuable:** coherent feature or fix, edited source with real logic, config
  the user clearly tuned, docs, anything referenced by a branch name or recent commits.
- **Untracked files:** decide per file. Secrets or artifacts belong in `.gitignore`,
  not the repo; real new source is probably valuable.

## Step 3: categorize and recommend

Assign the repo's pending work to one of three categories and say why:

- **K1: safe to discard** (high confidence it is throwaway)
- **K2: unsure** (could go either way, needs the user's eyes)
- **K3: keep** (clearly valuable, should be committed or pushed)

Then give a concrete, per-repo recommendation, for example:
- K1: "Recommend discarding: this is only a debug `println` and a stray `.log`."
- K3: "Recommend committing: coherent change to `auth.rs`, matches branch `fix/login`.
  Suggested message: `fix(auth): reject expired tokens`. Also 2 unpushed commits: push after?"
- never-pushed branch: "Branch `feature/x` was never pushed. Push to origin, keep local, or drop?"

## Step 4: human in the loop, one decision per repo

Ask the user what to do with THIS repo. Offer the concrete actions that fit its state,
such as: **commit** (you propose the message), **stage a subset then commit**, **push**,
**stash**, **add to `.gitignore`**, **discard** (spell out exactly what is lost),
**leave as-is**, or **skip**. Wait for their answer. Only then run the chosen command.

- If they choose commit: show the exact `git add ...` and `git commit -m ...` you will
  run, then run it. Do not invent scope beyond what they approved.
- If they choose discard: restate what will be permanently lost and require a second
  confirmation before any destructive command.
- If they are unsure: leave it untouched and move on; it stays in K2.

Then move to the next repo.

## Step 5: wrap up

When all repos are done, summarize: what was committed, pushed, stashed, discarded, and
what was intentionally left. List anything still in K2 (unsure) so the user knows what
remains open. Do not push a "clean everything" agenda; leaving work untouched is a valid
outcome.
