# Envi Shell
A clean shell environment that can be deployed with a single command. 

### Warning
The installation will require root rights. If you don't trust this system don't use it. 

## Requirements
You need to have `curl` and `git` installed.

## Installation
Easiest way is to execute the following: 
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/master/setup/install.sh)"
``` 
This will clone the repository to `$HOME` and execute the setup script. 

### Alternative
If you want to be able to make changes and push them, you can fork it first, clone it, and execute `setup/install.sh` manually.
