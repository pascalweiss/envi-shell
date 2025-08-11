#!/usr/bin/env bash
#
# HOMEBREW INITIALIZATION
# =======================
# Homebrew package manager integration and environment setup
# Auto-detects Homebrew installation and loads environment

# Homebrew Integration
# Configure environment based on available Homebrew installation paths
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi