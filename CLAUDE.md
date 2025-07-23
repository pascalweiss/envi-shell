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

### Git Workflow (Primary Development Commands)
```bash
# Check all changes across project and submodules
./run/git_diff_all.sh

# Commit all changes with same message
./run/git_commit_all.sh "commit message"

# Push all repositories (submodules first, then main)
./run/git_push_all.sh

# Force pull all repositories (destructive - overwrites local changes)
./run/git_force_pull_all.sh
```

### Complete Workflow
```bash
# Typical development cycle
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

The project uses three submodules managed collectively:
- **dotfiles**: Shell themes and configurations
- **envi-vim**: Vim configuration and plugins  
- **fake-server**: Development HTTP server

All automation scripts handle proper submodule → main project commit ordering to ensure submodule references stay synchronized.