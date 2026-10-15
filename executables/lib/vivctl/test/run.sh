#!/usr/bin/env bash
#
# Live test suite for vivctl.
# =============================================================================
#   executables/lib/vivctl/test/run.sh          run everything
#   executables/lib/vivctl/test/run.sh --keep   keep the temp directory afterwards
#
# It starts its own daemon on a throwaway Vivaldi profile in a temp directory, serves the
# pages in site/ from its own local web server, and needs no network. It never touches a
# real profile: VIVCTL_PROFILE and VIVCTL_HOME point into the temp directory, and the lock
# is off (or answered by a script) only for that throwaway daemon. Vivaldi windows appear on
# screen while it runs, about two minutes.
#
# Run it after every Vivaldi update. The Vivaldi calls vivctl relies on are undocumented, and
# a changed one shows up here as a failure instead of as a quietly wrong browser.
# =============================================================================

set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MJS="$HERE/../vivctl.mjs"
KEEP=false; [ "${1:-}" = "--keep" ] && KEEP=true

TMP="$(mktemp -d "${TMPDIR:-/tmp}/vivctl-test.XXXXXX")"
export VIVCTL_PROFILE="$TMP/profile" VIVCTL_HOME="$TMP/home" VIVCTL_AUTH=off
unset VIVCTL_AUTH_BIN VIVCTL_DENY VIVCTL_LEASE_MINUTES
ERR="$TMP/client-errors.log"
mkdir -p "$VIVCTL_PROFILE" "$TMP/site"; : > "$ERR"

# --- local web server --------------------------------------------------------
cp "$HERE"/site/*.html "$TMP/site/"
python3 -c "import sys;open(sys.argv[1],'w').write('<!doctype html><title>Long</title><body>'+''.join(f'<p>Paragraph {i} '+'lorem ipsum '*20+'</p>' for i in range(2000))+'</body>')" "$TMP/site/long.html"
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
URL="http://127.0.0.1:$PORT"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$TMP/site" >/dev/null 2>&1 &
SERVER=$!

# Every call's stderr also lands in ERR, so an internal error (a stack trace rather than a
# user message) counts as a failure even when the end state happens to look right.
v(){ node "$MJS" "$@" 2> >(tee -a "$ERR" >&2); }

cleanup(){
    echo 0 > "$TMP/auth-answer" 2>/dev/null
    v unlock >/dev/null 2>&1; v stop >/dev/null 2>&1
    for _ in $(seq 1 20); do v status >/dev/null 2>&1 || break; sleep 0.5; done
    kill "$SERVER" 2>/dev/null
    if $KEEP; then echo "kept $TMP"; else rm -rf "$TMP"; fi
}
trap cleanup EXIT

pass=0; fail=0; skip=0
check(){ # check NAME EXPECTED-SUBSTRING ACTUAL
    if [[ "$3" == *"$2"* ]]; then pass=$((pass+1)); echo "ok    $1"
    else fail=$((fail+1)); echo "FAIL  $1: wanted [$2] got [${3:0:200}]"; fi
}
check_not(){ # check_not NAME UNWANTED-SUBSTRING ACTUAL
    if [[ "$3" != *"$2"* ]]; then pass=$((pass+1)); echo "ok    $1"
    else fail=$((fail+1)); echo "FAIL  $1: did not want [$2] in [${3:0:200}]"; fi
}
tabid(){ grep -o '[0-9]\{6,\}' | head -1; }
jq_(){ python3 -c "import sys,json;d=json.load(sys.stdin);$1"; }
# one stack as "title|color|sorted tab ids|id prefix", or "none"
stack_of(){ v stacks --json | jq_ "l=[s for s in d if s['title'].lower()=='$1'.lower()];print(l[0]['title']+'|'+l[0]['color']+'|'+' '.join(map(str,sorted(l[0]['tabs'])))+'|'+l[0]['id'][:8] if l else 'none')"; }
size_of(){ stack_of "$1" | cut -d'|' -f3 | wc -w | tr -d ' '; }
group_of(){ v tabs --json | jq_ "print([t.get('group') or 'none' for t in d if t['id']==$1][0])"; }
sorted(){ echo "$@" | tr ' ' '\n' | sort -n | tr '\n' ' ' | sed 's/ $//'; }

echo "== start"
v start >/dev/null
check "daemon ready" "ready" "$(v status)"
# a tab outside every stack, so that closing test tabs never closes the window
KEEPALIVE="$(v open "$URL/second.html?t=keepalive" | tabid)"

echo "== stacks"
check "open as new stack" "stack:" "$(v open "$URL/second.html?t=s1" "$URL/second.html?t=s2" --stack Regress --color teal)"
check "stacks shows it" "teal    Regress" "$(v stacks)"
check "open into stack" "stack:" "$(v open "$URL/second.html?t=s3" --stack regress)"
check "stack has 3 tabs" "3" "$(size_of Regress)"
v title regress "Regress 2" >/dev/null; v color "regress 2" orange >/dev/null
check "rename and recolor" "orange  Regress 2" "$(v stacks)"
v unstack "regress 2" >/dev/null
check_not "unstack" "Regress 2" "$(v stacks)"
v open "$URL/second.html?t=w1" "$URL/second.html?t=w2" --stack Gone >/dev/null; v close-stack gone >/dev/null
check "close-stack" "no stack" "$(v title gone x 2>&1)"
check "one URL cannot create a stack" "give two or more URLs" "$(v open "$URL/second.html?t=x" --stack Missing 2>&1)"
check "unknown color" "unknown color" "$(v color x pink2 2>&1)"

echo "== stacks are never mixed up with the active tab's stack"
v open "$URL/second.html?t=m1" "$URL/second.html?t=m2" --stack "Meeting Notes" --color purple >/dev/null
MN="$(stack_of 'Meeting Notes')"; M1="$(echo "$MN" | cut -d'|' -f3 | cut -d' ' -f1)"
v focus "$M1" >/dev/null
P="$(v open "$URL/second.html?t=plain" | tabid)"
check "plain open: foreign stack unchanged" "$MN" "$(stack_of 'Meeting Notes')"
check "plain open: new tab in no stack" "none" "$(group_of "$P")"
v focus "$M1" >/dev/null
check "open --stack: no error" "stack:" "$(v open "$URL/second.html?t=r1" "$URL/second.html?t=r2" --stack Research --color yellow 2>&1)"
check "open --stack: foreign stack unchanged" "$MN" "$(stack_of 'Meeting Notes')"
check "open --stack: new stack has exactly the new tabs" "Research|yellow|" "$(stack_of Research)"
check "open --stack: two tabs" "2" "$(size_of Research)"
v focus "$M1" >/dev/null; v open "$URL/second.html?t=r3" --stack research >/dev/null
check "join while another stack is active: that stack unchanged" "$MN" "$(stack_of 'Meeting Notes')"
check "join: three tabs, title and color kept" "Research|yellow|" "$(stack_of Research)"
check "join: size" "3" "$(size_of Research)"
v focus "$KEEPALIVE" >/dev/null
v open "$URL/second.html?t=n1" "$URL/second.html?t=n2" --stack New --color green >/dev/null
check "new stack from an unstacked active tab" "2" "$(size_of New)"
v focus "$M1" >/dev/null
A="$(v open "$URL/second.html?t=a" | tabid)"; B="$(v open "$URL/second.html?t=b" | tabid)"
v stack "$A" "$B" --title X --color red >/dev/null
check "stack IDs: foreign stack unchanged" "$MN" "$(stack_of 'Meeting Notes')"
check "stack IDs: exactly these tabs" "X|red|$(sorted "$A" "$B")|" "$(stack_of X)"
C="$(v open "$URL/second.html?t=into" | tabid)"; v stack "$C" --into "meeting notes" >/dev/null
check "--into joins and keeps the title" "Meeting Notes|purple|" "$(stack_of 'Meeting Notes')"
check "--into adds one tab" "3" "$(size_of 'Meeting Notes')"
XID="$(stack_of X | cut -d'|' -f4)"; v stack "$A" "$B" --title X2 >/dev/null
check "same tabs again: renamed" "X2|red|" "$(stack_of X2)"
check "same tabs again: same stack" "$XID" "$(stack_of X2)"
MID="$(stack_of 'Meeting Notes' | cut -d'|' -f4)"; RID="$(stack_of Research | cut -d'|' -f4)"
v stack "$M1" "$(stack_of Research | cut -d'|' -f3 | cut -d' ' -f1)" --title Mix --color blue >/dev/null
check "across stacks: new stack of two" "2" "$(size_of Mix)"
check "across stacks: first old stack keeps id and name" "Meeting Notes|purple|" "$(stack_of 'Meeting Notes')"
check "across stacks: first old stack id" "$MID" "$(stack_of 'Meeting Notes')"
check "across stacks: second old stack id" "$RID" "$(stack_of Research)"

echo "== pages (all in background tabs)"
T="$(v open "$URL/" | tabid)"; FM="$(v open "$URL/form.html" | tabid)"
SH="$(v open "$URL/shadow.html" | tabid)"; FR="$(v open "$URL/frame.html" | tabid)"
H="$(v open "$URL/hostile.html" | tabid)"; K="$(v open "$URL/keys.html" | tabid)"
TD="$(v open "$URL/todo.html" | tabid)"; LG="$(v open "$URL/long.html" | tabid)"
sleep 2
check "read" "Hello vivctl" "$(v read "$T")"
check "elements" "[3] input:password Password" "$(v elements "$T")"
check "query stripped" "second.html?..." "$(v elements "$T")"
v type "$T" 2 Pascal >/dev/null; v click "$T" 4 >/dev/null
check "type and click" "Hello Pascal!" "$(v read "$T")"
check "password refused" "refusing" "$(v type "$T" 3 secret 2>&1)"
check "stale ref" "gone" "$(v click "$T" 99 2>&1)"
check "bad scheme" "only http(s)" "$(v navigate "$T" file:///etc/hosts 2>&1)"
check "checkbox label from <label>" "input:checkbox Agree" "$(v elements "$FM")"
check "select by text" "Blue" "$(v select "$FM" 2 blue)"
check "covered element is not clicked" "is covered by" "$(v click "$FM" 5 2>&1)"
v click "$FM" 5 --force >/dev/null
check "--force clicks from the page" "clicked under the banner" "$(v read "$FM")"
check "click reports a new tab" "newTabs" "$(v click "$FM" 6)"
v type "$FM" 4 "new text" >/dev/null
check "contenteditable" "new text" "$(v read "$FM")"
check "Enter submits the form" "submitted: true" "$(v type "$FM" 1 term --enter)"
check "after submit the tab shows the result" "second.html?..." "$(v tabs | grep "^$FM")"
check "shadow DOM elements" "Shadow button" "$(v elements "$SH")"
v type "$SH" 1 "in the shadow" >/dev/null; v click "$SH" 2 >/dev/null
check "shadow DOM type and click" "Shadow: in the shadow" "$(v read "$SH")"
check "iframe elements" "Frame button" "$(v elements "$FR")"
v type "$FR" 1 "in the frame" >/dev/null; v click "$FR" 2 >/dev/null
check "iframe type and click" "Frame: in the frame" "$(v read "$FR")"
v elements "$H" >/dev/null; v click "$H" 2 >/dev/null
check "hostile page: one click counted once" "1" "$(v read "$H" | tail -1)"
v elements "$TD" >/dev/null
check "keydown handler sees Enter in a background tab" "enter:" "$(v type "$TD" 1 "buy milk" --enter)"
check "keydown handler added the item" "buy milk" "$(v read "$TD")"
v elements "$K" >/dev/null; v type "$K" 1 x >/dev/null
check "key in a background tab is scripted" "via: 'script'" "$(v press "$K" ArrowDown)"
check "scroll" "max:" "$(v scroll "$LG" bottom)"
check "long page truncated" "truncated" "$(v read "$LG")"
check "focus" "{}" "$(v focus "$K")"
v elements "$K" >/dev/null; v type "$K" 1 y >/dev/null
check "key in the front tab is real" "via: 'keyboard'" "$(v press "$K" ArrowDown)"
check "the page saw a trusted key" "trusted=true" "$(v read "$K")"
f="$(v screenshot "$K")"; check "screenshot" "PNG image" "$(file "$f")"
DA="$(v open "$URL/" | tabid)"; DB="$(v open "$URL/" | tabid)"; sleep 1
v elements "$DA" >/dev/null; v type "$DA" 2 AAA >/dev/null; v click "$DA" 4 >/dev/null
check "same page twice: first tab" "Hello AAA!" "$(v read "$DA")"
check "same page twice: second tab" "nothing yet" "$(v read "$DB")"
check "same page twice: titles restored" "Test page" "$(v tabs | grep "^$DB")"
check "navigate" "Page two" "$(v navigate "$T" "$URL/second.html")"
v back "$T" >/dev/null
check "back" "Test page" "$(v read "$T" | head -1)"

echo "== windows and move"
wins(){ v windows --json | jq_ "print(len(d))"; }
win_of(){ v tabs --json | jq_ "print([t['windowId'] for t in d if t['id']==$1][0])"; }
W1="$(v windows --json | jq_ "print(d[0]['id'])")"
check "windows lists one window" "1" "$(wins)"
v open "$URL/second.html?t=mv1" "$URL/second.html?t=mv2" --stack Mover --color teal >/dev/null
MV="$(stack_of Mover)"; MV_TABS="$(echo "$MV" | cut -d'|' -f3)"
out="$(v move --stack mover --to new)"
check "move a stack to a new window" "window:" "$out"
check "now two windows" "2" "$(wins)"
W2="$(v windows --json | jq_ "print([w['id'] for w in d if w['id']!=$W1][0])")"
check "the stack is a stack in the new window, same title, color and tabs" "Mover|teal|$MV_TABS|" "$(stack_of Mover)"
check "its tabs are in the new window" "$W2" "$(win_of "$(echo "$MV_TABS" | cut -d' ' -f1)")"
v open "$URL/second.html?t=p1" "$URL/second.html?t=p2" "$URL/second.html?t=p3" --stack Partial --color red >/dev/null
PA="$(stack_of Partial)"; P1="$(echo "$PA" | cut -d'|' -f3 | cut -d' ' -f1)"
v move "$P1" --to "$W2" >/dev/null
check "one tab out of a stack: the stack keeps its other tabs and its id" "Partial|red|$(echo "$PA" | cut -d'|' -f3 | cut -d' ' -f2-)|$(echo "$PA" | cut -d'|' -f4)" "$(stack_of Partial)"
check "the moved tab is in no stack" "none" "$(group_of "$P1")"
check "and in the other window" "$W2" "$(win_of "$P1")"
N="$(v tabs --json | jq_ "print(len(d))")"
check "merge a window into another" "window:" "$(v move --window "$W1" --to "$W2")"
check "one window left" "1" "$(wins)"
check "no tab lost" "$N" "$(v tabs --json | jq_ "print(len(d))")"
check "stacks survive the merge" "Mover|teal|$MV_TABS|" "$(stack_of Mover)"
check "move needs exactly one source" "exactly one" "$(v move --to new 2>&1)"
check "move needs a target" "--to" "$(v move "$P1" 2>&1)"
check "unknown window" "no window" "$(v move "$P1" --to 12345 2>&1)"
check "window ids are numbers" "not a window id" "$(v move "$P1" --to abc 2>&1)"

echo "== no window open"
ALL="$(v tabs --json | jq_ "print(' '.join(str(t['id']) for t in d))")"
# shellcheck disable=SC2086
v close $ALL >/dev/null; sleep 2
check "status says no window" "no window open" "$(v status)"
check "tabs is empty, not an error" "[]" "$(v tabs --json)"
check "open brings a window back" "tabs:" "$(v open "$URL/second.html?t=back")"
check "status ready again" "ready" "$(v status)"

echo "== lock, and tabs restored after a restart"
v stop >/dev/null; for _ in $(seq 1 20); do v status >/dev/null 2>&1 || break; sleep 0.5; done
printf '#!/bin/sh\nexit "$(cat "%s")"\n' "$TMP/auth-answer" > "$TMP/auth.sh"; chmod +x "$TMP/auth.sh"
echo 1 > "$TMP/auth-answer"
VIVCTL_AUTH= VIVCTL_AUTH_BIN="$TMP/auth.sh" v start >/dev/null
check "starts locked" "locked" "$(v status)"
for c in "tabs" "windows" "open $URL/" "read 1" "click 1 1" "type 1 1 x" "select 1 1 x" "scroll 1 down" "stack 1 2" "move 1 --to new" "stop"; do
    # shellcheck disable=SC2086
    check "locked: $c" "locked" "$(v $c 2>&1)"
done
check "refused unlock stays locked" "unlock failed" "$(v unlock 2>&1)"
echo 0 > "$TMP/auth-answer"
check "unlock" "unlocked" "$(v unlock)"
U="$(v tabs --json | jq_ "l=[t['id'] for t in d if t['status']=='unloaded'];print(l[0] if l else '')")"
if [ -n "$U" ]; then
    check "restored tab that is not loaded is reported" "not loaded" "$(v read "$U" 2>&1)"
    v reload "$U" >/dev/null; sleep 1
    check_not "reload loads it" "not loaded" "$(v read "$U" 2>&1)"
else
    skip=$((skip+1)); echo "skip  no unloaded tab after the restart (session not restored?)"
fi

internal="$(grep -c 'vivctl: Error' "$ERR")"
if [ "$internal" -gt 0 ]; then
    fail=$((fail+internal)); echo "FAIL  $internal internal error(s):"; grep 'vivctl: Error' "$ERR" | sort | uniq -c
fi
echo "---- $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
