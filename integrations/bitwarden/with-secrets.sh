#!/usr/bin/env bash

# ======================================================== #
# ========= Run Command With Bitwarden Secrets =========== #
# ======================================================== #
#
# Wrapper that injects secrets from a dedicated (AI-only) Bitwarden vault into
# any command. Uses a background agent (ssh-agent pattern) to hold the secrets
# in memory. Secrets are NEVER written to disk.
#
# Cross-platform: pure bash + bw + python3 (+ jq for field: refs). The unlock
# is `bw unlock` with the master password on the CLI — identical on macOS and
# Linux, so this runs unchanged on headless Linux servers (no biometrics).
#
# Usage (exposed system-wide as the `bw-run` executable in executables/bin):
#   bw-run <command> [args...]
#   bw-run --agent-status
#   bw-run --stop-agent
#
# How it works:
#   1. First call: `bw unlock` (you type the master password ONCE), then each
#      reference in $BW_ENV_FILE is resolved via `bw get`. The resulting secrets
#      are handed to a background agent that holds them in memory. The BW session
#      key lives only in this shell process and is discarded immediately after.
#   2. Subsequent calls: secrets are read from the agent via a Unix socket
#      (no master password, no `bw`, no disk).
#   3. Agent auto-exits after the TTL (BW_SECRET_AGENT_TTL, default 1h).
#
# On disk (NO secrets):
#   - <runtime-dir>/.bw-secret-agent.sock   (Unix socket, filesystem entry only)
#   - <runtime-dir>/.bw-secret-agent.pid    (PID number only)
#   runtime-dir = $XDG_RUNTIME_DIR (Linux) or $TMPDIR (macOS) or /tmp
#
# Prerequisites:
#   - Bitwarden CLI (bw), python3, and jq (only for field: references)
#   - Logged in to the AI-only account ONCE:  bw login <email>
#     (the bw CLI is single-account; keep it logged into the AI vault only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BW_ENV_FILE="${BW_ENV_FILE:-$SCRIPT_DIR/bw-env}"
AGENT_SCRIPT="$SCRIPT_DIR/secret-agent.py"
AGENT_TTL="${BW_SECRET_AGENT_TTL:-3600}" # 1 hour default

# Prefer XDG_RUNTIME_DIR (Linux: tmpfs, per-user, short path — ideal for sockets),
# then TMPDIR (macOS), then /tmp. Short paths matter: AF_UNIX caps at ~104 chars.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
RUNTIME_DIR="${RUNTIME_DIR%/}"
SOCK_PATH="$RUNTIME_DIR/.bw-secret-agent.sock"
PID_PATH="$RUNTIME_DIR/.bw-secret-agent.pid"

# ~~~~~~~~~~~~~~~~~~~~~~ Helpers ~~~~~~~~~~~~~~~~~~~~~~ #

die() { echo "Error: $*" >&2; exit 1; }

# Check if the agent is running and responsive
agent_is_running() {
  [ -S "$SOCK_PATH" ] || return 1
  [ -f "$PID_PATH" ] || return 1
  local pid
  pid=$(cat "$PID_PATH" 2>/dev/null) || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  return 0
}

# Resolve one .bw-env reference to its value, given a session key.
# Supported reference syntax (right-hand side of each .bw-env line):
#   password:<item>        -> bw get password <item>   (also the default, no prefix)
#   username:<item>        -> bw get username <item>
#   totp:<item>            -> bw get totp <item>
#   notes:<item>           -> bw get notes <item>
#   field:<name>:<item>    -> custom field <name> of <item> (via bw get item + jq)
# <item> may be an item name or an item ID.
resolve_one() {
  local ref="$1" session="$2"
  local kind rest item

  if [[ "$ref" == *:* ]]; then
    kind="${ref%%:*}"
    rest="${ref#*:}"
  else
    kind="password"
    rest="$ref"
  fi

  case "$kind" in
    password|username|totp|notes)
      item="$rest"
      bw get "$kind" "$item" --session "$session"
      ;;
    field)
      # field:<name>:<item>
      local fname="${rest%%:*}"
      item="${rest#*:}"
      [ "$item" != "$rest" ] || die "field reference needs form field:<name>:<item>: $ref"
      command -v jq >/dev/null 2>&1 || die "jq is required for field: references (brew install jq / apt install jq)"
      bw get item "$item" --session "$session" \
        | jq -r --arg n "$fname" '.fields[] | select(.name==$n) | .value'
      ;;
    *)
      die "unknown reference kind '$kind' in .bw-env (use password|username|totp|notes|field)"
      ;;
  esac
}

# Unlock Bitwarden (master password prompt) and resolve all secrets to JSON.
resolve_secrets_json() {
  echo "" >&2
  echo "=== Bitwarden Secret Agent ===" >&2
  echo "Unlocking the AI vault. Enter your master password when prompted." >&2
  echo "==============================" >&2
  echo "" >&2

  # Fail early if not logged in.
  local status
  status=$(bw status 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  if [ "$status" = "unauthenticated" ] || [ -z "$status" ]; then
    die "bw is not logged in. Run once: bw login <ai-account-email>"
  fi

  # Unlock once; capture the session key on stdout, prompt goes to the tty.
  local session
  session=$(bw unlock --raw) || die "bw unlock failed (wrong master password?)"
  [ -n "$session" ] || die "bw unlock returned an empty session key"

  # Refresh the local vault cache so newly-added items are visible. Best-effort:
  # if offline, keep going with whatever is cached rather than failing the run.
  if ! bw sync --session "$session" >/dev/null 2>&1; then
    echo "warning: bw sync failed (offline?) — using cached vault" >&2
  fi

  local json="{"
  local first=true

  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue      # skip comments
    [[ -z "${line// /}" ]] && continue               # skip blank lines

    local var_name="${line%%=*}"
    local secret_ref="${line#*=}"
    var_name="${var_name//[[:space:]]/}"                       # trim ws
    secret_ref="${secret_ref#"${secret_ref%%[![:space:]]*}"}"  # ltrim ws

    local value
    if ! value=$(resolve_one "$secret_ref" "$session" 2>&1); then
      die "Failed to resolve $var_name ($secret_ref) from Bitwarden: $value"
    fi
    [ -n "$value" ] || die "Resolved an empty value for $var_name ($secret_ref)"

    value=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$value")

    if [ "$first" = true ]; then first=false; else json+=","; fi
    json+="\"$var_name\":$value"
  done < "$BW_ENV_FILE"

  json+="}"

  unset session   # drop the session key from this shell immediately
  echo "$json"
}

start_agent() {
  local secrets_json
  secrets_json=$(resolve_secrets_json)
  echo "$secrets_json" | python3 "$AGENT_SCRIPT" "$SOCK_PATH" "$PID_PATH" "$AGENT_TTL" >&2
}

load_from_agent() {
  local secrets_json key value
  secrets_json=$(python3 "$AGENT_SCRIPT" --query "$SOCK_PATH")

  while IFS='=' read -r key value; do
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Error: invalid env var name '$key' — skipping" >&2
      continue
    fi
    export "$key=$value"
  done < <(python3 -c "
import json, sys
secrets = json.loads(sys.argv[1])
for k, v in secrets.items():
    print(f'{k}={v}')
" "$secrets_json")
}

stop_agent() {
  python3 "$AGENT_SCRIPT" --stop "$SOCK_PATH" "$PID_PATH"
}

# ~~~~~~~~~~~~~~~~~~~~~~~ Main ~~~~~~~~~~~~~~~~~~~~~~~~ #

run_shell=false
case "${1:-}" in
  --stop-agent)
    stop_agent
    exit 0
    ;;
  --agent-status)
    if agent_is_running; then
      echo "Agent running (PID $(cat "$PID_PATH" 2>/dev/null), socket $SOCK_PATH)"
    else
      echo "Agent not running"
    fi
    exit 0
    ;;
  --shell)
    # Drop into an interactive shell with the secrets loaded, so you can use
    # $VAR directly without wrapping every command in bash -c '...'.
    run_shell=true
    shift
    ;;
  "")
    echo "Usage: bw-run <command> [args...]"
    echo ""
    echo "Options:"
    echo "  --shell          Open a shell with the secrets loaded (use \$VAR directly)"
    echo "  --stop-agent     Stop the background secret agent (wipes secrets from memory)"
    echo "  --agent-status   Check if the agent is running"
    exit 1
    ;;
esac

# Validate prerequisites
command -v bw &> /dev/null || die "Bitwarden CLI (bw) not found. Install: brew install bitwarden-cli"
command -v python3 &> /dev/null || die "Python 3 not found."
[ -f "$BW_ENV_FILE" ] || die "bw-env file not found at $BW_ENV_FILE (copy bw-env.example to bw-env and edit it)"

# Ensure agent is running (start if needed), then run the command with secrets
if ! agent_is_running; then
  start_agent
fi
load_from_agent

if [ "$run_shell" = true ]; then
  exec "${SHELL:-/bin/bash}"
else
  exec "$@"
fi
