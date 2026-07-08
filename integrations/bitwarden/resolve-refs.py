#!/usr/bin/env python3

"""
resolve-refs.py — extract one bw-env reference from a pre-fetched vault dump.

bw-run resolves every secret in bw-env once per unlock. Spawning `bw get` per
reference is the dominant cost of an unlock, because each `bw` invocation pays a
~2-3s Node cold start. Instead, bw-run runs `bw list items` ONCE and pipes that
JSON array into this helper per reference, so all lookups are local (no extra
`bw` spawn). totp is the one exception — it must be computed from the seed, so
bw-run still calls `bw get totp` for those and never routes them here.

Usage (called by bw-run.sh, not directly):
    <items-json on stdin> | resolve-refs.py <kind> <rest>

    kind = password | username | notes | field
    rest = the item name-or-id, except for `field` where it is "<name>:<item>"

Contract:
    stdout : the resolved value (no trailing newline added), on success (exit 0)
    stderr : a short reason, on failure (exit 1)
The value is only ever written to stdout and is never logged.
"""

import json
import sys


def die(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(1)


def find_item(items, selector):
    # References may name an item by its name OR its id (same as `bw get`).
    for it in items:
        if it.get("name") == selector or it.get("id") == selector:
            return it
    return None


def main():
    if len(sys.argv) < 3:
        die("usage: resolve-refs.py <kind> <rest>  (items JSON on stdin)")
    kind, rest = sys.argv[1], sys.argv[2]

    try:
        items = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError) as e:
        die(f"could not parse `bw list items` output: {e}")
    if not isinstance(items, list):
        die("expected a JSON array from `bw list items`")

    if kind == "field":
        fname, sep, selector = rest.partition(":")
        if not sep or not selector:
            die("field reference needs the form field:<name>:<item>")
        it = find_item(items, selector)
        if it is None:
            die(f"item not found: {selector}")
        for f in (it.get("fields") or []):
            if f.get("name") == fname:
                val = f.get("value")
                if val:
                    sys.stdout.write(val)
                    return
                die(f"field '{fname}' is empty")
        die(f"field '{fname}' not found on item")

    it = find_item(items, rest)
    if it is None:
        die(f"item not found: {rest}")

    if kind == "password":
        val = (it.get("login") or {}).get("password")
    elif kind == "username":
        val = (it.get("login") or {}).get("username")
    elif kind == "notes":
        val = it.get("notes")
    else:
        die(f"unknown reference kind '{kind}' (use password|username|totp|notes|field)")

    if not val:
        die(f"empty {kind} for item: {rest}")
    sys.stdout.write(val)


if __name__ == "__main__":
    main()
