#!/usr/bin/env bash
#
# NEOVIM INITIALIZATION
# =====================
# Neovim editor configuration and aliases
# Sets up VIMINIT, editor environment variables, and vim aliases

# Use VIMINIT to load user config if exists, otherwise load defaults
export VIMINIT="lua if vim.fn.filereadable('$ENVI_HOME/config/.envi_nvim') == 1 then dofile('$ENVI_HOME/config/.envi_nvim') else dofile('$ENVI_HOME/defaults/default_nvim.lua') end"

# Set neovim as default editor
export EDITOR=nvim
export VISUAL=nvim

# Create vim alias to nvim (most portable approach)
alias vim='nvim'
alias vi='nvim'