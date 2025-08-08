# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Envi Shell is a cross-platform development environment setup system written in Bash. It provides automated shell environment configuration, custom commands, and git workflow automation for multi-repository projects with submodules.

## Architecture

**Core Components:**
- **Setup System** (`setup/`): Modular installation with interactive user configuration
- **Runtime Environment** (`executables/sbin/enviinit`): Environment initialization loaded by shell
- **Automation Scripts** (`run/`): Git workflow management for project + submodules
- **Configuration Management**: User configs in `config/`, defaults in `defaults/`
- **Submodules**: Separate repositories for dotfiles, vim config, and fake-server

**Key Design Patterns:**
- Modular setup functions (`setup/_func_*.sh`) for different installation components
- Platform-specific executables organized by OS (`linuxbin/`, `macbin/`, universal `bin/`)
- Template-based configuration system for user customization
- Proper submodule commit ordering (submodules first, then main project)

## Development Commands

### Installation
```bash
# Remote installation
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"

# Local installation
./setup/install.sh
```

### Git Workflow (DEFAULT GIT APPROACH - Use These Commands)
```bash
# Check all changes across project and submodules (REQUIRED - use instead of git status/diff)
./run/git_diff_all.sh

# Commit all changes with same message (REQUIRED - use instead of git commit)
./run/git_commit_all.sh "commit message"

# Push all repositories (REQUIRED - use instead of git push)
./run/git_push_all.sh

# Force pull all repositories (destructive - overwrites local changes)
./run/git_force_pull_all.sh
```

### Complete Workflow (ALWAYS USE THIS FOR GIT OPERATIONS)
```bash
# Typical development cycle (REQUIRED workflow)
./run/git_diff_all.sh && \
./run/git_commit_all.sh "Your commit message" && \
./run/git_push_all.sh
```

## Project Structure

- **`setup/`**: Interactive installation system with modular functions
- **`executables/`**: Custom commands organized by platform compatibility
- **`run/`**: Git automation scripts for multi-repository management
- **`defaults/`**: Default configurations and package lists
- **`config/`**: User-specific configuration files
- **`submodules/`**: Three git submodules (dotfiles, envi-vim, fake-server)

## Custom Commands Available After Installation

- `git whoami` - Show current git user info
- `renamenice [FILES...]` - Normalize filenames (lowercase, underscores, umlaut conversion)
- `fake-server <port>` - Start development HTTP server in Docker
- `netinfo` - Display network interface information

## Configuration Files

- **`.gitmodules`**: Defines three submodules with main branch tracking
- **`defaults/packages_os.txt`**: OS packages installed during setup
- **`setup/templates/envi_rc`**: Main environment configuration template
- **`config/.envi_shortcuts`**: User-defined aliases and functions
- **`executables/sbin/enviinit`**: Runtime initialization sourced by shell

## Submodule Management

The project uses two submodules managed collectively:
- **dotfiles**: Shell themes and configurations (config-files repository)
- **envi-vim**: Vim configuration and plugins

All automation scripts handle proper submodule → main project commit ordering to ensure submodule references stay synchronized.

## Shell Initialization Flow

**IMPORTANT: Keep this section updated when modifying shell initialization logic**

The envi system follows a specific execution order during shell startup to ensure proper loading of configurations and features:

```
Shell startup (.bashrc/.zshrc)
  ↓
source ~/.envi_rc  
  ↓
enviinit: Load user config FIRST → Set environment → NO interactive features
  ├── Load config/.envi_env (variables like TMUX_ENABLED, SSH_AGENT_ENABLED)
  ├── Load config/.envi_locations and config/.envi_shortcuts  
  ├── Set PATH, colors, UTF-8 locale
  └── Oh-My-Zsh theme linking
  ↓  
Oh-My-Zsh framework loading (zsh only)
  ↓
Powerlevel10k theme loading (if POWERLEVEL10K_ENABLED=true, zsh only)
  ↓
envi_post_init: Interactive session features only
  ├── SSH agent startup (if SSH_AGENT_ENABLED=true)
  └── Tmux auto-start (if TMUX_ENABLED=true)
```

### Feature Control Variables

All features can be enabled/disabled via environment variables in `config/.envi_env`:

- `SSH_AGENT_ENABLED=true/false` - Control SSH agent auto-start (interactive shells only)
- `POWERLEVEL10K_ENABLED=true/false` - Control Powerlevel10k theme loading (zsh only)
- `TMUX_ENABLED=true/false` - Control tmux auto-start (interactive shells only)  
- `TMUX_AUTO_ATTACH=true/false` - Auto-attach to existing tmux sessions (disabled by default)
- `TMUX_SHOW_HELP=true/false` - Show tmux help before starting session

### Key Implementation Details

- **enviinit** runs for ALL shell instances (interactive and non-interactive) - only put universal environment setup here
- **envi_post_init** runs only for interactive shells (`[ -n "$PS1" ]`) - put user-facing features here
- **Variable loading order**: User config loaded FIRST in enviinit so variables are available to all subsequent logic
- **No exec commands**: Tmux commands don't use `exec` to allow shell initialization to complete
- **Boolean variables**: All boolean checks use string comparison `[ "$VAR" = "true" ]` for consistency and robustness
