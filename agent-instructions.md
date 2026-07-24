# Agent instructions for this machine

Global guidance for any coding agent (Claude Code, Codex, Gemini CLI, OpenCode)
running on this machine. Each envi-provided tool is documented in its **own** file
under `agent-instructions/`, so a machine can opt into exactly the tools it wants
(see "How this is wired" below). This file is the top-level index: it lists every
available tool and points to its detail file. The detail files are the single source
of truth, so they can be edited freely and changes take effect immediately with no
re-provisioning.

## Quick routing: symptom to tool

Map the situation to the right tool before falling back to asking the user. The trigger
is the *symptom*, not a keyword: an ssh push failure or a "need a token" situation is a
credential task even when it does not look like one. Read the linked file for details.

| Situation / symptom | Tool | Read |
| --- | --- | --- |
| Need a token / API key / credential (GitLab, GitHub, Atlassian/Jira, Paperless, ...), or a `git push`/`git fetch` fails with `Permission denied (publickey)` | `bw-run` | [agent-instructions/bw-run.md](agent-instructions/bw-run.md) |
| A command needs to run on a remote host (server, k8s node) | `erun` | [agent-instructions/erun.md](agent-instructions/erun.md) |
| Which repos on this machine have uncommitted, unpushed or never-pushed work | `gitscan` | [agent-instructions/gitscan.md](agent-instructions/gitscan.md) |

A CLI that already carries its own auth (e.g. `glab` logged in, `kubectl` with a working
kubeconfig) needs none of these: just use it.

## How this is wired (per-machine tool selection)

The tools above are not universally desirable: some machines (e.g. a work laptop) should
not use `bw-run`. Selection is therefore per machine, and works two ways:

- **Automatic**, via `envi-agent-notes`: it injects a managed block listing the selected
  tools into each installed agent's global config (`~/.claude/CLAUDE.md`,
  `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.config/opencode/AGENTS.md`). The
  selection is controlled by `ENVI_AGENT_TOOLS` in `~/.envi/config/envi_env`:
    - `ENVI_AGENT_TOOLS="all"`            (default) inject every tool
    - `ENVI_AGENT_TOOLS="erun gitscan"`   inject only these; `bw-run` is never mentioned
    - `ENVI_AGENT_TOOLS="none"`           inject nothing
  Re-run `envi-agent-notes` after changing it. Only a routing block plus links is injected
  (never the full prose), so editing a tool file still takes effect instantly.
- **Manual**: link the tool files you want directly from your own agents.md / CLAUDE.md.
  Link this index (`~/.envi/agent-instructions.md`) to reference everything, or link
  individual files under `~/.envi/agent-instructions/` to opt in tool by tool.

### Adding a new tool
Create `agent-instructions/<tool>.md` starting with a header line
`<!-- envi-tool: <name> | <one-line when-to-use> -->`, then add a row to the routing
table above. `envi-agent-notes` reads that header to build the injected routing entry,
so no code change is needed.
