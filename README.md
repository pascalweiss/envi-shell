# Envi Shell
A clean shell environment that can be deployed with a single command. 

### Warning
The installation will require root rights. If you don't trust this system don't use it. 

## Installation
Easiest way is to execute the following: 
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/master/setup/install.sh)"
``` 
This will clone the repository and execute the setup script. 

### Alternative
If you want to be able to make changes and push them, you can fork it first, clone it, and execute `setup/install.sh` manually.

## TODO
- New setup procedure: First collect all answers from user input, thereby generate array with all packages. Then do all installation procedures in one step at the end
- deploy vs-code config (add vs-code to repo config-files)
- README: add a table with all commands and verfication if they are tested on various OSs
- add hammerspoon to mac setup
