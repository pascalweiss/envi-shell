#!/usr/bin/env bash

# ======================================================== #
# ========= Run Command With Bitwarden Secrets =========== #
# ======================================================== #
#
# Wrapper that injects secrets from a dedicated (AI-only) Bitwarden vault into
# any command. Uses a background agent (ssh-agent pattern) to hold the secrets
# in memory. Secrets are NEVER written to disk.
#
# Cross-platform: pure bash + bw + python3 (+ jq for field: refs). By default the
# unlock is `bw unlock` with the master password on the CLI, identical on macOS
# and Linux, so this runs unchanged on headless Linux servers (no biometrics).
# On macOS you can opt into Touch ID unlock (see `bw-run --setup-touchid` and
# keychain-touchid.swift): the master password is stored in the login Keychain and
# released only after a fingerprint check, replacing the password prompt.
#
# Usage (exposed system-wide as the `bw-run` executable in executables/bin):
#   bw-run <command> [args...]
#   bw-run --agent-status
#   bw-run --stop-agent
#   bw-run --setup-touchid | --remove-touchid | --touchid-status   (macOS)
#
# How it works:
#   1. First call: `bw unlock` (you authenticate ONCE via master password, or via
#      Touch ID on macOS if set up), then each reference in $BW_ENV_FILE is
#      resolved via `bw get`. The resulting secrets are handed to a background
#      agent that holds them in memory. The BW session key lives only in this
#      shell process and is discarded immediately after.
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
KEYCHAIN_HELPER="$SCRIPT_DIR/keychain-touchid.swift"
TOUCHID_RACE="$SCRIPT_DIR/touchid-race.py"

# Touch ID unlock (macOS only): store the master password in the login Keychain,
# release it only after a Touch ID check, so unlocking needs a fingerprint instead
# of typing the master password each TTL. Opt-in via `bw-run --setup-touchid`.
#   auto  = use it when a password has been stored (default; no-op until set up)
#   true  = same as auto (kept for symmetry)
#   false = never use it (always prompt for the master password)
: "${BW_TOUCHID_ENABLED:=auto}"
# Backstop timeout (seconds) for the Touch ID sheet. When you choose Touch ID at
# the unlock prompt and then neither tap nor cancel, the sheet is dismissed after
# this many seconds and it falls back to the master password.
: "${BW_TOUCHID_TIMEOUT:=30}"

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

# ~~~~~~~~~~~~~~~~ Touch ID unlock (macOS) ~~~~~~~~~~~~~~~ #

# Keychain account = the bw account email, so the stored password is scoped to the
# exact account the CLI is logged into (fixed label fallback if bw is unavailable).
bw_account_email() {
  local email
  email=$(bw status 2>/dev/null \
    | python3 -c "import json,sys;print(json.load(sys.stdin).get('userEmail') or '')" 2>/dev/null) || email=""
  [ -n "$email" ] && printf '%s' "$email" || printf '%s' "bw-master"
}

# True when Touch ID unlock should be attempted for this run. Memoized: it is
# called from both the banner and unlock_session, and each swift launch costs ~1s.
# Biometric availability itself is NOT probed here (that also costs a swift launch);
# the `get` path checks it and falls back to a password prompt if unavailable.
_TOUCHID_CACHE=""
touchid_should_use() {
  case "$_TOUCHID_CACHE" in yes) return 0 ;; no) return 1 ;; esac
  if _touchid_should_use; then _TOUCHID_CACHE=yes; return 0; fi
  _TOUCHID_CACHE=no; return 1
}
_touchid_should_use() {
  [ "$(uname -s)" = "Darwin" ] || return 1
  case "$BW_TOUCHID_ENABLED" in false|0|no|off) return 1 ;; esac
  command -v swift >/dev/null 2>&1 || return 1
  [ -f "$KEYCHAIN_HELPER" ] || return 1
  # Only engage once a password has actually been stored for this account.
  swift "$KEYCHAIN_HELPER" check "$(bw_account_email)" >/dev/null 2>&1 || return 1
  return 0
}

# Obtain a bw session key. On macOS with Touch ID configured, run the Python helper
# that shows the sheet and races the fingerprint against a keypress: place your
# finger to unlock (no keyboard), or press any key to abort to the master password
# (the only escape over SSH). On a tap the helper prints the stored master password
# on stdout (exit 0); anything else (keypress / cancel / timeout / no tty) falls
# back to `bw unlock`'s prompt. The helper owns the terminal (no-echo, and it
# flushes typed-ahead), so nothing typed can leak into the password prompt. Writes
# the raw session key to stdout; diagnostics to stderr.
unlock_session() {
  local account pw session
  if touchid_should_use && command -v python3 >/dev/null 2>&1; then
    account=$(bw_account_email)
    if pw=$(python3 "$TOUCHID_RACE" "$KEYCHAIN_HELPER" "$account" "$BW_TOUCHID_TIMEOUT") && [ -n "$pw" ]; then
      if session=$(BW_MASTER_PW="$pw" bw unlock --passwordenv BW_MASTER_PW --raw 2>/dev/null); then
        unset pw
        printf '%s' "$session"
        return 0
      fi
      unset pw
      echo "warning: stored master password did not unlock (rotated?)." >&2
      echo "         Re-run 'bw-run --setup-touchid' to update it. Using the prompt." >&2
    fi
  fi
  bw unlock --raw
}

setup_touchid() {
  [ "$(uname -s)" = "Darwin" ] || die "Touch ID unlock is macOS-only."
  command -v swift >/dev/null 2>&1 || die "swift not found. Install Xcode Command Line Tools: xcode-select --install"
  command -v bw >/dev/null 2>&1 || die "Bitwarden CLI (bw) not found."
  [ -f "$KEYCHAIN_HELPER" ] || die "keychain helper not found at $KEYCHAIN_HELPER"
  swift "$KEYCHAIN_HELPER" canauth >/dev/null 2>&1 || die "No biometrics available (Touch ID not set up on this Mac)."

  local account; account=$(bw_account_email)
  echo "Setting up Touch ID unlock for the Bitwarden vault (account: $account)." >&2
  echo "Your master password is stored in the login Keychain and released only after" >&2
  echo "a Touch ID check. Enter it once now." >&2
  local pw
  printf 'Master password: ' >&2
  read -rs pw; echo >&2
  [ -n "$pw" ] || die "empty password — nothing stored."

  # Verify it actually unlocks before storing anything.
  if ! BW_MASTER_PW="$pw" bw unlock --passwordenv BW_MASTER_PW --raw >/dev/null 2>&1; then
    unset pw
    die "That password did not unlock the vault — nothing stored."
  fi
  if ! printf '%s' "$pw" | swift "$KEYCHAIN_HELPER" store "$account"; then
    unset pw
    die "Failed to store the password in the Keychain."
  fi
  unset pw
  echo "✓ Stored. 'bw-run' will now unlock via Touch ID on this Mac." >&2
  echo "  Disable per-machine with BW_TOUCHID_ENABLED=false; remove with 'bw-run --remove-touchid'." >&2
}

remove_touchid() {
  [ "$(uname -s)" = "Darwin" ] || die "Touch ID unlock is macOS-only."
  [ -f "$KEYCHAIN_HELPER" ] || die "keychain helper not found at $KEYCHAIN_HELPER"
  local account; account=$(bw_account_email)
  if swift "$KEYCHAIN_HELPER" delete "$account" >/dev/null 2>&1; then
    echo "✓ Removed the stored master password ($account)." >&2
  else
    echo "No stored master password to remove ($account)." >&2
  fi
}

touchid_status() {
  if [ "$(uname -s)" != "Darwin" ]; then echo "Touch ID unlock: unsupported (not macOS)"; return; fi
  local account bio stored
  account=$(bw_account_email)
  bio="no";    swift "$KEYCHAIN_HELPER" canauth >/dev/null 2>&1 && bio="yes"
  stored="no"; swift "$KEYCHAIN_HELPER" check "$account" >/dev/null 2>&1 && stored="yes"
  echo "Touch ID unlock (macOS):"
  echo "  BW_TOUCHID_ENABLED           = $BW_TOUCHID_ENABLED"
  echo "  biometrics available         = $bio"
  echo "  password stored for account  = $stored ($account)"
  echo "  sheet timeout (BW_TOUCHID_TIMEOUT) = ${BW_TOUCHID_TIMEOUT}s"
  if touchid_should_use; then
    echo "  -> next unlock: Touch ID sheet (tap to unlock, or press any key for the password)"
  else
    echo "  -> next unlock: master-password prompt"
  fi
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
  if touchid_should_use; then
    echo "Unlocking the AI vault." >&2
  else
    echo "Unlocking the AI vault. Enter your master password when prompted." >&2
  fi
  echo "==============================" >&2
  echo "" >&2

  # Fail early if not logged in.
  local status
  status=$(bw status 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  if [ "$status" = "unauthenticated" ] || [ -z "$status" ]; then
    die "bw is not logged in. Run once: bw login <ai-account-email>"
  fi

  # Unlock once (Touch ID on macOS if configured, else master-password prompt).
  # Capture the session key on stdout; any prompt goes to the tty / GUI.
  local session
  session=$(unlock_session) || die "bw unlock failed (wrong master password?)"
  [ -n "$session" ] || die "bw unlock returned an empty session key"

  echo "Syncing vault and fetching secrets (a few seconds)..." >&2

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
  --setup-touchid)
    setup_touchid
    exit 0
    ;;
  --remove-touchid)
    remove_touchid
    exit 0
    ;;
  --touchid-status)
    touchid_status
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
    echo "  --shell           Open a shell with the secrets loaded (use \$VAR directly)"
    echo "  --stop-agent      Stop the background secret agent (wipes secrets from memory)"
    echo "  --agent-status    Check if the agent is running"
    echo "  --setup-touchid   (macOS) store the master password behind Touch ID for unlock"
    echo "  --remove-touchid  (macOS) remove the Touch ID stored master password"
    echo "  --touchid-status  (macOS) show whether Touch ID unlock is active"
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
