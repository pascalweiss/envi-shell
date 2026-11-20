#!/usr/bin/env bash
#
# ZSH AND OH-MY-ZSH INITIALIZATION
# ================================
# Configures and loads Oh-My-Zsh framework with envi customizations
# Called from enviinit when OHMYZSH_ENABLED=true

# Defaults -- overridden only if user sets them in config/envi_env.
# fzf-tab must be last so it wraps completion-related widgets registered
# by earlier plugins.
: "${OHMYZSH_ENABLED:=true}"
: "${OHMYZSH_THEME_LINKING:=true}"
: "${OHMYZSH_PLUGINS:=git kubectl zsh-autosuggestions fzf-tab}"
: "${OHMYZSH_GIT_PROMPT_CACHE:=true}"
: "${ZSH_THEME:=envi-minimal}"
export OHMYZSH_ENABLED OHMYZSH_THEME_LINKING OHMYZSH_PLUGINS OHMYZSH_GIT_PROMPT_CACHE ZSH_THEME

# Oh-My-Zsh framework loading and configuration (zsh only)
if [ "$OHMYZSH_ENABLED" = "true" ] && [ -n "${ZSH_VERSION:-}" ] && [ -n "$ZSH" ]; then
    # Set custom directory for Oh-My-Zsh plugins and themes BEFORE configuring plugins
    export ZSH_CUSTOM="$ZSH/custom"
    
    # Configure plugins from OHMYZSH_PLUGINS variable BEFORE loading Oh-My-Zsh
    if [ -n "$OHMYZSH_PLUGINS" ]; then
        # Convert space-separated string to zsh array format using word splitting
        plugins=(${=OHMYZSH_PLUGINS})
    fi
    
    # Git prompt cache optimization
    if [ "$OHMYZSH_GIT_PROMPT_CACHE" = "true" ]; then
        export ZSH_THEME_GIT_PROMPT_CACHE=yes
    fi
    
    # Theme linking - creates symlinks for custom themes BEFORE loading Oh-My-Zsh
    if [ "$OHMYZSH_THEME_LINKING" = "true" ] && [ -n "$ZSH_THEME" ]; then
        # Create symlink from envi themes to Oh-My-Zsh themes directory
        if [ -e "$ZSH" ] && [ ! -e "$ZSH/themes/$ZSH_THEME.zsh-theme" ] && [ -e "$ENVI_HOME/integrations/zsh/themes/$ZSH_THEME.zsh-theme" ]; then
            ln -sf "$ENVI_HOME/integrations/zsh/themes/$ZSH_THEME.zsh-theme" "$ZSH/themes/"
        fi
        # Fallback to default theme if custom theme is not available
        if [ ! -e "$ZSH/themes/$ZSH_THEME.zsh-theme" ]; then
            export ZSH_THEME="robbyrussell"
        fi
    elif [ -z "$ZSH_THEME" ]; then
        # Set default theme if not defined
        export ZSH_THEME="robbyrussell"
    fi

    # Normalize fpath before Oh-My-Zsh runs compinit:
    # 1. Un-export FPATH (`brew shellenv` in ~/.zprofile exports it). When FPATH
    #    is exported, tmux inherits post-compinit additions (such as fzf-tab/lib)
    #    and passes them into every new pane BEFORE compinit, causing Oh-My-Zsh's
    #    `_omz_compdump_has_metadata` check to fail and rebuild zcompdump (~385ms)
    #    on every single pane split. Note: `-g` is required because this file is
    #    sourced from inside `envi_full_init()`, where `typeset` without `-g`
    #    would shadow `path` / `fpath` as empty function-local variables!
    # 2. Strip any pre-existing $ZSH/* entries inherited from a parent shell or
    #    tmux server so oh-my-zsh.sh builds the exact same pre-compinit fpath on
    #    every invocation, and deduplicate `fpath` and `path`.
    if [ -n "${ZSH_VERSION:-}" ]; then
        typeset -g +x FPATH 2>/dev/null || true
        fpath=(${fpath:#$ZSH/*})
        typeset -gU path fpath
    fi

    # Load Oh-My-Zsh framework (replaces source $ZSH/oh-my-zsh.sh from .zshrc)
    if [ -f "$ZSH/oh-my-zsh.sh" ]; then
        source "$ZSH/oh-my-zsh.sh"
    fi
    
fi
