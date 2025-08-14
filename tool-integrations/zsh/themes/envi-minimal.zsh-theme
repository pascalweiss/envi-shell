# MINIMAL ENVI THEME
# Designed to work with tmux status bar - no duplicate information
# Features: Static timestamp and command number

# Enable prompt substitution
setopt PROMPT_SUBST

# Minimal prompt with static timestamp; chevrons color depends on OS

# Set chevrons to purple on Linux, otherwise keep bright green
case "$OSTYPE" in
    linux*) envi_chevron_color="%{$fg_bold[magenta]%}" ;;
    *)      envi_chevron_color="%{$fg_bold[green]%}" ;;
esac

PROMPT='%{$fg[white]%}[%{$fg_bold[cyan]%}⌘ %h%{$reset_color%} %{$fg[white]%}│%{$reset_color%} %{$fg_bold[blue]%}%D{%H:%M:%S}%{$reset_color%}%{$fg[white]%}]%{$reset_color%} ${envi_chevron_color}❯❯❯%{$reset_color%} '

# Clean right prompt - no extra info (tmux has it all)
RPS1=''

# Secondary prompt for multi-line commands
PS2='${accent_color}│${reset_color} '

# Selection prompt
PS3='${prompt_color}?${reset_color} '

# Execution trace prompt
PS4='${accent_color}+${reset_color} '
