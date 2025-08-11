# Envi Shell
A clean shell environment that can be deployed with a single command. This project provides a comprehensive development environment with integrated submodules and automation scripts. Test change.

### Warning
The installation will require root rights. If you don't trust this system don't use it. 

## Requirements
You need to have `curl` and `git` installed.

## Installation
Easiest way is to execute the following: 
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"
``` 
This will clone the repository to `$HOME` and execute the setup script. 

### Alternative
If you want to be able to make changes and push them, you can fork it first, clone it, and execute `setup/install.sh` manually.

## Features
- An installation setup where you can choose what to install
- A set of useful command line tools, functions and aliases
- The ability to define custom aliases and functions
- Integrated submodule management with automation scripts
- Git workflow automation for multi-repository projects

### Commands
- `git whoami` - provides the current git user and email with single command
- `renamenice [FILES...]`- This script renames files by converting their names to lowercase, replacing spaces and special characters with underscores,
  and converting German umlauts into their respective letter combinations (ä -> ae, ü -> ue, ö -> oe).
  Multiple underscores are reduced to a single underscore.
- `fake-server <port>` - Starts a simple http server that logs every request for the given port to the console. Runs in a docker
- `netinfo`- Prints out for the current net interface: LAN IP, WAN IP, broadcast, MAC address
- `tt` - Interactive tmux session manager with fzf (press 'a' to attach, 'k' to kill sessions)  

## Automation Scripts (run/ folder)
The `run/` folder contains automation scripts for managing the entire project and its submodules:

### Git Management Scripts
- **`git_diff_all.sh`** - Shows git status and diffs for the main project and all submodules
  - Displays staged and unstaged changes
  - Provides summary of files with changes across all repositories
  - No pager interruption - all output printed directly to terminal

- **`git_commit_all.sh`** - Commits changes across all repositories with a single commit message
  - Prompts for commit message (supports quoted messages)
  - Commits submodules first, then main project (ensuring submodule references are updated)
  - Adds all new and modified files automatically
  - Handles detached HEAD state in submodules
  - Includes comprehensive help documentation

- **`git_push_all.sh`** - Pushes committed changes from all repositories to their remotes
  - Pushes submodules first, then main project
  - Supports both regular push and force push (with safety confirmation)
  - Skips repositories with no commits to push
  - Handles detached HEAD state gracefully
  - Provides detailed feedback on push results

- **`git_force_pull_all.sh`** - Force pulls latest changes from all remote repositories
  - **WARNING**: Overwrites all local changes without merge conflicts
  - Updates main project and all submodules to match remote state exactly
  - Includes safety confirmation prompt
  - Updates submodule references in main project

### Usage Examples
```bash
# Check all changes across project and submodules
./run/git_diff_all.sh

# Commit all changes with same message (interactive)
./run/git_commit_all.sh

# Commit all changes with quoted message (command line)
./run/git_commit_all.sh "Your commit message here"

# Push all committed changes to remotes
./run/git_push_all.sh

# Force push (use with caution!)
./run/git_push_all.sh --force

# Force sync with remote (discards local changes)
./run/git_force_pull_all.sh

# Show help for any script
./run/git_commit_all.sh --help
./run/git_push_all.sh --help
```

### Complete Git Workflow
The scripts are designed to work together for a complete git workflow:

```bash
# 1. Check what changes you have
./run/git_diff_all.sh

# 2. Commit all changes with a descriptive message
./run/git_commit_all.sh "Add new feature and update documentation"

# 3. Push all changes to remote repositories
./run/git_push_all.sh

# Alternative: Do it all in one go
./run/git_diff_all.sh && \
./run/git_commit_all.sh "Your commit message" && \
./run/git_push_all.sh
```

**Key Benefits:**
- **Unified workflow** across main project + all submodules
- **Proper ordering** ensures submodule references are always up-to-date
- **Safety features** prevent common git mistakes with submodules
- **Comprehensive feedback** shows exactly what was changed/committed/pushed  


## Integrated Submodules
This project uses submodules to organize related components:

- **dotfiles** - Configuration files and shell themes
  - Location: `submodules/dotfiles/`
  - Repository: https://github.com/pascalweiss/config-files

- **fake-server** - Development HTTP server for testing
  - Location: `submodules/fake-server/`
  - Repository: https://github.com/pascalweiss/fake-server/

All submodules use `main` as their default branch and can be managed collectively using the automation scripts in the `run/` folder.
