# tmux preferences
use_tmux="yes"
show_tmux_help="yes"
if [ "$use_tmux"=yes ]; then 
  [[ $TERM != "screen" ]] && exec tmux;  
fi;
if [ "$show_tmux_help"=yes ]; then
   echo "c create window"
   echo "w list window"
   echo "n next window"
   echo "p previous window"
   echo "% vertical split"
   echo "\" horizontal split"
   echo "o swap panes"
   echo "q show pane numbers"    
   echo "x kill pane"
   echo "_ -space- toggle between layouts"
fi;

# avoid duplicates..
export HISTCONTROL=ignoredups:erasedups

# append history entries..
shopt -s histappend

# After each command, save and reload history
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

#edit loc.sh
alias loc='vim ~/scr/loc.sh'

#edit aliases.sh
alias short='vim ~/scr/shortcuts.sh'

# requests translation from dict.cc and writes request in vocab.log
en() {
   vocab=~/vocab.log
   args1=""
   args2=""
   for arg in "$@"
   do
      args1="${args1}+$arg"
      args2="${args2} $arg"
   done
   printf "`date` - $args2\n" >> $vocab
   dict.cc.py en de $args1
}

# firefox shortcut
ff() {
   firefox $1 &
}

# search with firefox
www() {
   link="https://www.google.de/?gws_rd=ssl#q="
   for arg in "$@"
   do 
      link="${link}+$arg"
   done   
   firefox $link &
}

# copies sparkRContext.R to working directory
sparkRContext() {
   cp ~/scr/sparkRContext.R `pwd`
}
# various
alias o='gnome-open'


