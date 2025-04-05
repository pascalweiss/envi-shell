# Envi Shell
A clean shell environment that can be deployed with a single command. 

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

### Commands
- `git whoami` - provides the current git user and email with single command
- `renamenice [FILES...]`- This script renames files by converting their names to lowercase, replacing spaces and special characters with underscores,
  and converting German umlauts into their respective letter combinations (ä -> ae, ü -> ue, ö -> oe).
  Multiple underscores are reduced to a single underscore.
- `fake-server <port>` - Starts a simple http server that logs every request for the given port to the console. Runs in a docker
- `netinfo`- Prints out for the current net interface: LAN IP, WAN IP, broadcast, MAC address  


## Integrated Submodules
- https://github.com/pascalweiss/config-files
- https://github.com/pascalweiss/envi-vim/
- https://github.com/pascalweiss/fake-server/