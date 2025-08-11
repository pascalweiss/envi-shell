#!/usr/bin/env bash
#
# ZSH AND OH-MY-ZSH INITIALIZATION
# ================================
# Configures and loads Oh-My-Zsh framework with envi customizations
# Called from enviinit when OHMYZSH_ENABLED=true

# Oh-My-Zsh framework loading and configuration (zsh only)
if [ "$OHMYZSH_ENABLED" = "true" ] && [ -n "$ZSH" ]; then
    # Configure plugins from OHMYZSH_PLUGINS variable BEFORE loading Oh-My-Zsh
    if [ -n "$OHMYZSH_PLUGINS" ]; then
        # Convert space-separated string to zsh array format
        export plugins=(${=OHMYZSH_PLUGINS})
    fi
    
    # Git prompt cache optimization
    if [ "$OHMYZSH_GIT_PROMPT_CACHE" = "true" ]; then
        export ZSH_THEME_GIT_PROMPT_CACHE=yes
    fi
    
    # Theme linking - creates symlinks for custom themes BEFORE loading Oh-My-Zsh
    if [ "$OHMYZSH_THEME_LINKING" = "true" ] && [ -n "$ZSH_THEME" ]; then
        # Create symlink from envi themes to Oh-My-Zsh themes directory
        if [ -e "$ZSH" ] && [ ! -e "$ZSH/themes/$ZSH_THEME.zsh-theme" ] && [ -e "$ENVI_HOME/tool-integrations/zsh/themes/$ZSH_THEME.zsh-theme" ]; then
            ln -s "$ENVI_HOME/tool-integrations/zsh/themes/$ZSH_THEME.zsh-theme" "$ZSH/themes/"
        fi
        # Fallback to default theme if custom theme is not available
        if [ ! -e "$ZSH/themes/$ZSH_THEME.zsh-theme" ]; then
            export ZSH_THEME="robbyrussell"
        fi
    elif [ -z "$ZSH_THEME" ]; then
        # Set default theme if not defined
        export ZSH_THEME="robbyrussell"
    fi
    
    # Load Oh-My-Zsh framework (replaces source $ZSH/oh-my-zsh.sh from .zshrc)
    if [ -f "$ZSH/oh-my-zsh.sh" ]; then
        source "$ZSH/oh-my-zsh.sh"
    fi
    
fi