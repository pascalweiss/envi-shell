#!/usr/bin/env bash
#
# EZA INITIALIZATION
# ==================
# eza is a modern `ls` replacement with git status, icons, tree view.
# This integration installs convenience aliases.
#
# Controlled via EZA_ENABLED (default: true). No-op if eza is not
# installed.

: "${EZA_ENABLED:=true}"
export EZA_ENABLED

if [ "$EZA_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v eza >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

# Suppress eza's default background highlights on special files. Without
# this, `ls /dev` is a wall of solid color blocks because almost every
# entry is a block/char device, socket, or fifo.
export EZA_COLORS="bd=33:cd=33:so=35:pi=33:or=31"

# Wrap `ls` so GNU-style flag clusters from muscle memory (`-lath`, `-ltr`,
# `-lS`, ...) keep working under eza. We split each short-flag cluster into
# single letters and translate the ones eza spells differently:
#   t -> --sort=modified   S -> --sort=size   X -> --sort=extension
#   U -> --sort=none       r -> --reverse     h -> dropped (eza is human by default)
# Sort DIRECTION differs too: GNU `-t`/`-S` default to newest/largest first,
# eza's --sort defaults to the opposite, so those get an implicit --reverse
# that a user-supplied `r` then cancels (GNU `-ltr` = oldest first).
unalias ls 2>/dev/null
ls() {
    local -a passthrough=()
    local sort_key="" gnu_desc=0 rev=0 i c arg
    for arg in "$@"; do
        if [[ "$arg" == -?* && "$arg" != --* ]]; then   # short-flag cluster, not --long or a path
            for (( i=1; i<${#arg}; i++ )); do
                c="${arg:$i:1}"
                case "$c" in
                    t) sort_key=modified;  gnu_desc=1 ;;
                    S) sort_key=size;      gnu_desc=1 ;;
                    X) sort_key=extension; gnu_desc=0 ;;
                    U) sort_key=none;      gnu_desc=0 ;;
                    r) (( rev++ )) ;;
                    h) : ;;                        # eza sizes are human-readable by default
                    *) passthrough+=( "-$c" ) ;;
                esac
            done
        else
            passthrough+=( "$arg" )
        fi
    done
    local -a sortargs=()
    if [[ -n "$sort_key" ]]; then
        sortargs+=( "--sort=$sort_key" )
        (( (gnu_desc + rev) % 2 == 1 )) && sortargs+=( --reverse )
    elif (( rev % 2 == 1 )); then
        sortargs+=( --reverse )
    fi
    command eza "${passthrough[@]}" "${sortargs[@]}"
}
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
