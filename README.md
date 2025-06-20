# Envi Shell
A clean shell environment that can be deployed with a single command. This project provides a comprehensive development environment with integrated submodules and automation scripts.

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

## Automation Scripts (run/ folder)
The `run/` folder contains automation scripts for managing the entire project and its submodules:

### Git Management Scripts
- **`git_diff_all.sh`** - Shows git status and diffs for the main project and all submodules
  - Displays staged and unstaged changes
  - Provides summary of files with changes across all repositories
  - No pager interruption - all output printed directly to terminal

- **`git_commit_all.sh`** - Commits changes across all repositories with a single commit message
  - Prompts for commit message
  - Commits submodules first, then main project (ensuring submodule references are updated)
  - Adds all new and modified files automatically
  - Provides detailed feedback on what was committed

- **`git_force_pull_all.sh`** - Force pulls latest changes from all remote repositories
  - **WARNING**: Overwrites all local changes without merge conflicts
  - Updates main project and all submodules to match remote state exactly
  - Includes safety confirmation prompt
  - Updates submodule references in main project

### Usage Examples
```bash
# Check all changes across project and submodules
./run/git_diff_all.sh

# Commit all changes with same message
./run/git_commit_all.sh

# Force sync with remote (discards local changes)
./run/git_force_pull_all.sh
```  


## Integrated Submodules
This project uses submodules to organize related components:

- **dotfiles** - Configuration files and shell themes
  - Location: `submodules/dotfiles/`
  - Repository: https://github.com/pascalweiss/config-files

- **envi-vim** - Vim configuration and plugins
  - Location: `submodules/envi-vim/`
  - Repository: https://github.com/pascalweiss/envi-vim/

- **fake-server** - Development HTTP server for testing
  - Location: `submodules/fake-server/`
  - Repository: https://github.com/pascalweiss/fake-server/

All submodules use `main` as their default branch and can be managed collectively using the automation scripts in the `run/` folder.