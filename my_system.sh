#! /bin/bash

asksure() {
   echo -n "Are you sure (Y/N)? "
   while read -r -n 1 -s answer; do
     if [[ $answer = [YyNn] ]]; then
       [[ $answer = [Yy] ]] && retval=0
       [[ $answer = [Nn] ]] && retval=1
       break
     fi
   done
   
   echo # just a final linefeed, optics...
   
   return $retval
}


echo "This will install some applications and modify your .bashrc"
if asksure; then
   sudo apt-get update
   
   # Requirements for quitting apps from application-switcher wirt Alt+q
   sudo apt-get install xdotool
   sudo apt-get install compizconfig-settings-manager
   sudo apt-get install compiz plugins
   
   # various
   sudo pip install dict.cc.py
   sudo apt-get install tmux
   sudo apt-get install guake
   
   # adding shell shortcuts
   git clone https://github.com/pascalweiss/scr.git ~/scr
   
   echo "
   #location aliases
   . ~/scr/loc.sh
   
   # commands
   . ~/scr/shortcuts.sh" >> .bashrc
fi

