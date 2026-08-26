# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Envi Shell is a cross-platform development environment setup system written in Bash. It provides automated shell environment configuration, custom commands, and modular tool integrations.

## Architecture

**Core Components:**
- **Setup System** (`setup/`): Modular installation with interactive user configuration
- **Runtime Environment** (`executables/sbin/enviinit`): Environment initialization loaded by shell
- **Configuration Management**: User configs in `config/`, defaults in `defaults/`
- **Integrations** (`integrations/`): Modular, per-tool configuration and initialization (one subfolder per tool, each with an `init.sh` and any tool-specific config files like `tmux.conf`, `gitconfig`, or `config.toml`). Any setting that belongs to a specific external tool should live here, not in `enviinit` or `defaults/`. Tool configs that should be the same on every machine (atuin, tmux, zsh, git, ghostty, alacritty) are symlinked from the repo into the tool's expected location via the `link_with_backup` helper, so edits are versioned in git and synced across machines.

**Key Design Patterns:**
- Modular setup functions (`setup/_func_*.sh`) for different installation components
- Platform-specific executables organized by OS (`linuxbin/`, `macbin/`, universal `bin/`)
- Template-based configuration system for user customization
- Tool-specific initialization scripts in `integrations/*/init.sh`

## Development Commands

### Installation

**Requirements:** zsh is mandatory - envi-shell automatically installs Oh-My-Zsh and configures zsh as the default shell.

```bash
# Remote installation
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"

# Local installation
./setup/install.sh
```

### Git Workflow
```bash
# Check changes before committing
git diff && git status

# Commit changes with message
git add . && git commit -m "Your commit message"

# Push to remote
git push
```

### Complete Workflow
```bash
# Typical development cycle
git diff && git status && \
git add . && git commit -m "Your commit message" && \
git push
```

## Project Structure

- **`setup/`**: Interactive installation system with modular functions
- **`executables/`**: Custom commands organized by platform compatibility
- **`defaults/`**: Default configurations and package lists
- **`config/`**: User-specific configuration files
- **`agent-skills/`**: Coding-agent skills shipped by envi, one folder per skill (`<name>/SKILL.md`, the Claude/OpenCode skill format). `envi-agent-sync` symlinks the per-machine selection (`ENVI_AGENT_SKILLS`) into each installed agent's skill dir. See "Coding-agent integration" below.

## Coding-agent integration (agent-skills)

Envi ships knowledge and workflows for coding agents (Claude Code, OpenCode, ...) as
**skills**: `agent-skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`).
`description` is the discovery trigger, so it states *when* to use the skill. Both Claude
Code and OpenCode auto-discover skills from their skill dirs, so integration is done by
**symlink only** (`executables/bin/envi-agent-sync`), never by editing an agent's
instruction file (`CLAUDE.md` / `AGENTS.md`), which is deliberate: envi only touches files
it owns plus isolated per-skill symlinks.

- Selection is per machine via `ENVI_AGENT_SKILLS` (in `config/envi_env`): `all` (default),
  a subset like `erun gitscan repo-cleanup` (e.g. a work machine that must not use `bw-run`),
  or `none`.
- `envi-agent-sync` links selected skills into `~/.claude/skills` and
  `~/.config/opencode/skills`, removes deselected envi links, and never clobbers a real
  dir or a foreign symlink of the same name (ownership = symlink target points into
  `agent-skills/`).
- Add a skill: create `agent-skills/<name>/SKILL.md`, then run `envi-agent-sync`. A skill
  may reference an envi tool (e.g. `repo-cleanup` uses `gitscan`).
- **External sources**: `ENVI_AGENT_SKILL_SOURCES` (in `config/envi_env`) adds further skill
  dirs, space-separated and absolute. Their skills are linked exactly like envi's own, so a
  third-party skill repo can be exposed straight from its git clone (`git pull` in the clone
  is the whole update path, no copying). `agent-skills/` always comes first; on a name clash
  the first source wins and the duplicate is skipped with a warning. Ownership follows the
  current sources, so remove a source only after `envi-agent-sync --uninstall`, otherwise its
  links are orphaned. Which sources a given machine configures is a local decision and lives
  in its `config/envi_env`, not here. Where a skill in `agent-skills/` came from elsewhere, a
  `SOURCE.md` next to it records origin and licensing; that applies to skills whose upstream
  dropped them, which are maintained here from then on.

## Custom Commands Available After Installation

- `git whoami` - Show current git user info
- `renamenice [FILES...]` - Normalize filenames (lowercase, underscores, umlaut conversion)
- `fake-server <port>` - Start development HTTP server in Docker
- `netinfo` - Display network interface information
- `gitscan [ROOT...]` - Find every git repo (main / worktree / bare) and report uncommitted, unpushed or unpulled work. Default view shows only repos needing attention; `--all` lists clean ones, `--json`/`--porcelain` for agents/scripts. Discovery is pruned for speed and configurable via `GITSCAN_ROOTS`/`GITSCAN_MAX_DEPTH`/`GITSCAN_PRUNE`/`GITSCAN_JOBS`.
- `docscan <files-or-dir>` - **macOS only.** Turn photos of paper documents into clean scans: Vision detects the sheet, Core Image dewarps it and removes the shadow gradient. Writes to `<input>/cleaned`, never touches the originals, `--pdf` collects the pages. The command in `macbin/` is a wrapper; the tool is `executables/lib/docscan/docscan.swift`, compiled on first use into `DOCSCAN_CACHE` and rebuilt whenever the source checksum changes. Needs the Xcode Command Line Tools, nothing else.
- `envi-agent-sync` - Symlink agent skills (`agent-skills/*/SKILL.md` plus any dir in `ENVI_AGENT_SKILL_SOURCES`) into each installed agent's skill dir, per the `ENVI_AGENT_SKILLS` selection. `--list`/`--dry-run`/`--uninstall`. Only manages symlinks; never edits agent instruction files.

## Configuration Files

- **`defaults/packages_os_brew.txt`**: Homebrew formulas installed during setup (cross-platform)
- **`defaults/packages_os_brew_casks.txt`**: Homebrew casks (fonts, GUI apps); macOS-only, skipped on Linux
- **`config/envi_rc`**: Main environment configuration bootstrap file
- **`config/envi_shortcuts`**: User-defined aliases and functions
- **`executables/sbin/enviinit`**: Runtime initialization sourced by shell


## Shell Initialization Flow

**IMPORTANT: Keep this section updated when modifying shell initialization logic**

The envi system follows a specific execution order during shell startup to ensure proper loading of configurations and features:

```
Shell startup (.zshrc)
  ↓
source ~/.envi_rc
  ↓
enviinit: Complete environment initialization
  ├── Load config/envi_env (variables like TMUX_ENABLED, SSH_AGENT_ENABLED, ENVI_TMUX_ONLY)
  ├── Load config/envi_locations
  ├── Set PATH, colors, UTF-8 locale
  ├── Tool integrations (conditional based on ENVI_TMUX_ONLY)
  │   ├── Minimal mode (ENVI_TMUX_ONLY=true, outside tmux): Homebrew, SSH only
  │   └── Full mode (default or inside tmux): All tools including Oh-My-Zsh, fzf-tab, Atuin, zoxide, bat, eza, Node, etc.
  │       → Oh-My-Zsh loads HERE → compdef becomes available
  │       → fzf-tab zstyles applied AFTER OMZ (plugin itself is loaded via OHMYZSH_PLUGINS)
  │       → Atuin loads AFTER Oh-My-Zsh so its Up/Ctrl+R bindings win
  │       → zoxide/bat/eza follow; each integration is a no-op if its binary is missing
  ├── Shortcuts and completions (AFTER tool integrations!)
  │   ├── defaults/default_shortcuts.sh
  │   └── config/envi_shortcuts  ← compdef is available here
  └── Interactive features (SSH agent startup, tmux auto-start)
  ↓
Powerlevel10k theme loading (if POWERLEVEL10K_ENABLED=true, zsh only)
```

**IMPORTANT - Completion registrations in shortcuts:**
Shortcuts are intentionally loaded AFTER tool integrations so that Oh-My-Zsh (and therefore `compdef`) is already available. This means `config/envi_shortcuts` can safely use completion registrations like `source <(gardenctl completion zsh)` without needing guards. Do NOT move shortcuts loading back before tool integrations.

### Feature Control Variables

Envi-shipped defaults live next to their consumers using `: "${VAR:=default}"`:

- **enviinit** defines defaults for envi-wide vars it consumes: `ENVI_256_COLORS`, `ENVI_UTF_8`, `ENVI_TMUX_ONLY`, `TMUX_ENABLED`.
- **Each `integrations/<tool>/init.sh`** defines defaults for that tool: e.g. `OHMYZSH_PLUGINS` in zsh, `ATUIN_ENABLED` in atuin, `SSH_AGENT_ENABLED` in ssh, `TMUX_AUTO_ATTACH`/`TMUX_SHOW_HELP`/`TMUX_SPLIT_FOLLOW_PWD` in tmux.
- **`config/envi_env`** is for per-machine overrides only. Set a variable there to deviate from the envi default on that machine. Because `:=` only assigns when the var is unset, the user value wins.

This means new envi-shipped defaults (e.g. a new entry in `OHMYZSH_PLUGINS`) propagate to every machine on next `git pull && exec zsh`, without needing to edit each machine's `config/envi_env`. Per-machine pinning is still possible by setting the variable explicitly.

**Performance Optimization:**
- **`ENVI_TMUX_ONLY=false`** (default): Full initialization in all shells
- **`ENVI_TMUX_ONLY=true`**: Minimal initialization outside tmux, full initialization inside tmux
  - Prevents double initialization when creating tmux panes
  - Significantly speeds up shell startup when working primarily in tmux

### Key Implementation Details

- **enviinit** runs for ALL shell instances and handles everything - universal environment setup AND interactive features
- **Interactive features** within enviinit use `[ -n "$PS1" ]` checks to only run for interactive shells
- **Variable loading order**: Defaults loaded first, then user config to override defaults
- **No exec commands**: Tmux commands don't use `exec` to allow shell initialization to complete
- **Boolean variables**: All boolean checks use string comparison `[ "$VAR" = "true" ]` for consistency and robustness
- **Automatic tool loading**: NVM is automatically loaded if `~/.nvm/nvm.sh` exists (no configuration required)
