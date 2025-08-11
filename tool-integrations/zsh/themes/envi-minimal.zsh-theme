# MINIMAL ENVI THEME
# Designed to work with tmux status bar - no duplicate information
# Features: Live timestamp updates and command number

# Enable prompt substitution and set up periodic updates for live timestamp
setopt PROMPT_SUBST
TMOUT=1
TRAPALRM() {
    zle reset-prompt
}

# Colors for minimal aesthetic
local timestamp_color="%{$fg_bold[blue]%}"
local command_num_color="%{$fg_bold[cyan]%}"
local prompt_color="%{$fg_bold[green]%}"
local accent_color="%{$fg[white]%}"
local reset_color="%{$reset_color%}"

# Symbols
local separator="│"
local prompt_symbol="❯❯❯"
local number_symbol="⌘"

# Minimal prompt with live timestamp updates and static bright green chevrons
PROMPT='${accent_color}[${command_num_color}${number_symbol} %h${reset_color} ${accent_color}${separator}${reset_color} ${timestamp_color}%D{%H:%M:%S}${reset_color}${accent_color}]${reset_color} %{$fg_bold[green]%}${prompt_symbol}${reset_color} '

# Clean right prompt - no extra info (tmux has it all)
RPS1=''

# Secondary prompt for multi-line commands
PS2='${accent_color}│${reset_color} '

# Selection prompt
PS3='${prompt_color}?${reset_color} '

# Execution trace prompt
PS4='${accent_color}+${reset_color} '