#!/usr/bin/env bash
#
# BITWARDEN SECRET AGENT INITIALIZATION
# =====================================
# The `bw-run` command itself is a real executable in executables/bin (on envi's
# PATH), so it is available system-wide — in every shell and script, not just
# interactive zsh. This init.sh only ships the envi default for the agent TTL so
# it can be overridden per machine in config/envi_env.
# Called from enviinit for all shells.

: "${BW_SECRET_AGENT_TTL:=3600}"   # agent lifetime in seconds (1h)
export BW_SECRET_AGENT_TTL
