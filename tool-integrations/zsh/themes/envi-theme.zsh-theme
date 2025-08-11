# CYBERPUNK ELITE THEME
# Features: Neon colors, sleek design, futuristic aesthetic

# Generate colors based on hostname hash
generate_host_colors() {
  local hostname=$(hostname)
  local hash=$(echo -n "$hostname" | md5sum | cut -d' ' -f1)
  
  # Extract different parts of hash for different color components
  local hash1=${hash:0:2}   # First 2 chars
  local hash2=${hash:2:2}   # Next 2 chars  
  local hash3=${hash:4:2}   # Next 2 chars
  local hash4=${hash:6:2}   # Next 2 chars
  
  # Convert hex to decimal and map to color ranges
  local color1=$((0x$hash1 % 6 + 1))  # 1-6 for basic colors
  local color2=$((0x$hash2 % 6 + 1))  
  local color3=$((0x$hash3 % 6 + 1))
  local color4=$((0x$hash4 % 6 + 1))
  
  # Map numbers to color names
  local colors=(black red green yellow blue magenta cyan white)
  
  # Set colors based on hash - ensure good contrast
  case $color1 in
    1) user_color="%{$fg_bold[red]%}" ;;
    2) user_color="%{$fg_bold[green]%}" ;;
    3) user_color="%{$fg_bold[yellow]%}" ;;
    4) user_color="%{$fg_bold[blue]%}" ;;
    5) user_color="%{$fg_bold[magenta]%}" ;;
    6) user_color="%{$fg_bold[cyan]%}" ;;
  esac
  
  case $color2 in
    1) host_color="%{$fg_bold[cyan]%}" ;;
    2) host_color="%{$fg_bold[magenta]%}" ;;
    3) host_color="%{$fg_bold[blue]%}" ;;
    4) host_color="%{$fg_bold[yellow]%}" ;;
    5) host_color="%{$fg_bold[green]%}" ;;
    6) host_color="%{$fg_bold[red]%}" ;;
  esac
  
  case $color3 in
    1) dir_color="%{$fg_bold[blue]%}" ;;
    2) dir_color="%{$fg_bold[cyan]%}" ;;
    3) dir_color="%{$fg_bold[magenta]%}" ;;
    4) dir_color="%{$fg_bold[green]%}" ;;
    5) dir_color="%{$fg_bold[yellow]%}" ;;
    6) dir_color="%{$fg_bold[red]%}" ;;
  esac
  
  case $color4 in
    1) prompt_color="%{$fg_bold[magenta]%}" ;;
    2) prompt_color="%{$fg_bold[red]%}" ;;
    3) prompt_color="%{$fg_bold[cyan]%}" ;;
    4) prompt_color="%{$fg_bold[yellow]%}" ;;
    5) prompt_color="%{$fg_bold[green]%}" ;;
    6) prompt_color="%{$fg_bold[blue]%}" ;;
  esac
}

# Call function to generate colors
generate_host_colors

# Fixed colors (same across all machines)
local git_clean_color="%{$fg_bold[green]%}"
local git_dirty_color="%{$fg_bold[red]%}"
local git_branch_color="%{$fg_bold[yellow]%}"
local kube_color="%{$fg[blue]%}"
local accent_color="%{$fg[white]%}"
local time_color="%{$fg_bold[green]%}"
local reset_color="%{$reset_color%}"

# Futuristic symbols and separators
local branch_symbol=""
local kube_symbol="⬢"
local separator="⎪"
local prompt_symbol="❯"
local bullet="⬢"
local status_ok="✦"
local status_error="✖"

# Git status function with clean output
git_status_pro() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local git_state=""
    
    # Check for any changes (staged, unstaged, untracked)
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
      git_state="${git_dirty_color}${bullet}${reset_color}"
    else
      git_state="${git_clean_color}${bullet}${reset_color}"
    fi
    
    echo "─${accent_color}[${git_branch_color}${branch_symbol}${branch}${reset_color} ${git_state}${accent_color}]${reset_color}"
  fi
}

# Kubernetes context function
kube_context() {
  if command -v kubectl >/dev/null 2>&1; then
    local context=$(kubectl config current-context 2>/dev/null)
    if [[ -n "$context" ]]; then
      echo "─${accent_color}[${kube_color}${kube_symbol}${context}${reset_color}${accent_color}]${reset_color}"
    fi
  fi
}

# Responsive prompt function
set_responsive_prompt() {
  local term_width=$(tput cols 2>/dev/null || echo 80)
  
  if [[ $term_width -lt 90 ]]; then
    # Narrow terminal - show just current directory
    PROMPT='╭─${accent_color}[${user_color}%n${reset_color}${accent_color}@${host_color}%m${reset_color}${accent_color}]${reset_color}─${accent_color}[${dir_color}%1~${reset_color}${accent_color}]${reset_color}$(git_status_pro)
╰─${prompt_color}${prompt_symbol}${reset_color} '
  else
    # Wide terminal - show full path
    PROMPT='╭─${accent_color}[${user_color}%n${reset_color}${accent_color}@${host_color}%m${reset_color}${accent_color}]${reset_color}─${accent_color}[${dir_color}%~${reset_color}${accent_color}]${reset_color}$(git_status_pro)$(kube_context)
╰─${prompt_color}${prompt_symbol}${reset_color} '
  fi
}

# Hook to update prompt on terminal resize
precmd_functions+=(set_responsive_prompt)

# Initial prompt setup
set_responsive_prompt

# Right-side info with status
RPS1='${time_color}%T${reset_color} ${accent_color}${separator}${reset_color} %(?,${git_clean_color}${status_ok},${git_dirty_color}${status_error})${reset_color}'

# Secondary prompt for multi-line commands
PS2='${accent_color}│${reset_color} '

# Selection prompt
PS3='${prompt_color}?${reset_color} '

# Execution trace prompt
PS4='${accent_color}+${reset_color} '

# Standard git prompt configuration (for compatibility)
ZSH_THEME_GIT_PROMPT_PREFIX=" ${git_branch_color}${branch_symbol}"
ZSH_THEME_GIT_PROMPT_SUFFIX="${reset_color}"
ZSH_THEME_GIT_PROMPT_DIRTY="${git_dirty_color}${bullet}${reset_color}"
ZSH_THEME_GIT_PROMPT_CLEAN="${git_clean_color}${bullet}${reset_color}"