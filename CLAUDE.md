# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Envi Shell is a cross-platform development environment setup system written in Bash. It provides automated shell environment configuration, custom commands, and modular tool integrations.

## Architecture

**Core Components:**
- **Setup System** (`setup/`): Modular installation with interactive user configuration
- **Runtime Environment** (`executables/sbin/enviinit`): Environment initialization loaded by shell
- **Configuration Management**: User configs in `config/`, defaults in `defaults/`
- **Tool Integrations** (`tool-integrations/`): Modular configuration for development tools

**Key Design Patterns:**
- Modular setup functions (`setup/_func_*.sh`) for different installation components
- Platform-specific executables organized by OS (`linuxbin/`, `macbin/`, universal `bin/`)
- Template-based configuration system for user customization
- Tool-specific initialization scripts in `tool-integrations/*/init.sh`

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

## Custom Commands Available After Installation

- `git whoami` - Show current git user info
- `renamenice [FILES...]` - Normalize filenames (lowercase, underscores, umlaut conversion)
- `fake-server <port>` - Start development HTTP server in Docker
- `netinfo` - Display network interface information

## Configuration Files

- **`defaults/packages_os.txt`**: OS packages installed during setup
- **`setup/templates/envi_rc`**: Main environment configuration template
- **`config/.envi_shortcuts`**: User-defined aliases and functions
- **`executables/sbin/enviinit`**: Runtime initialization sourced by shell


## Shell Initialization Flow

**IMPORTANT: Keep this section updated when modifying shell initialization logic**

The envi system follows a specific execution order during shell startup to ensure proper loading of configurations and features:

```
Shell startup (.zshrc)
  ↓
source ~/.envi_rc  
  ↓
enviinit: Load defaults → Load user config → Set environment → NO interactive features
  ├── Load config/.envi_env (variables like TMUX_ENABLED, SSH_AGENT_ENABLED, OHMYZSH_*)
  ├── Load config/.envi_locations and config/.envi_shortcuts  
  ├── Set PATH, colors, UTF-8 locale
  └── Oh-My-Zsh configuration (plugins, git cache, theme linking)
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

All features can be enabled/disabled via environment variables in `config/.envi_env`.

### Key Implementation Details

- **enviinit** runs for ALL shell instances (interactive and non-interactive) - only put universal environment setup here
- **envi_post_init** runs only for interactive shells (`[ -n "$PS1" ]`) - put user-facing features here
- **Variable loading order**: Defaults loaded first, then user config to override defaults
- **No exec commands**: Tmux commands don't use `exec` to allow shell initialization to complete
- **Boolean variables**: All boolean checks use string comparison `[ "$VAR" = "true" ]` for consistency and robustness
- **Automatic tool loading**: NVM is automatically loaded if `~/.nvm/nvm.sh` exists (no configuration required)
