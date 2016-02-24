# tmux preferences
use_tmux=yes
show_tmux_help=yes
if [ "$use_tmux" = yes ]; then 
  [[ $TERM != "screen" ]] && exec tmux;  
fi
echo "c create window";
echo "w list window";
echo "n next window";
echo "p previous window";
echo "% vertical split";
echo "\" horizontal split";
echo "o swap panes";
echo "q show pane numbers";     
echo "x kill pane";
echo "_ -space- toggle between layouts";

#edit loc.sh
alias loc='vim ~/scr/loc.sh'

#edit aliases.sh
alias ali='vim ~/scr/aliases.sh'

# various aliases
alias en='dict.cc.py en de'
alias de='dict.cc.py de en'

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

alias o='gnome-open'


