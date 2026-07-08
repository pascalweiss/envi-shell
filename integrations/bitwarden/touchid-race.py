#!/usr/bin/env python3

"""
touchid-race.py — race a Touch ID prompt against a keypress, for bw-run.

Shows the macOS Touch ID sheet (via keychain-touchid.swift) and, at the same
time, watches the controlling terminal for a keypress:

  * place your finger on the sensor  -> unlock with the fingerprint (no keyboard)
  * press any key                    -> abort to the master-password prompt
                                        (the only escape over SSH, where you
                                         cannot tap)

Why Python and not bash: this needs to wait on TWO things at once (the swift
subprocess's stdout and the terminal) and to put the tty in no-echo/cbreak mode
and restore it reliably. `select` + `termios` do that cleanly and portably;
the bash equivalent (FIFO + raw `read` race) leaked typed-ahead into the later
password prompt and could not disable echo safely.

When there is no controlling terminal (a script or coding agent invoking
bw-run), there is no keyboard for the keypress escape. By default we bail so the
caller falls back to the master-password prompt. But if the optional [headless]
flag is truthy, we instead show a *bare* Touch ID sheet (no keypress race, no
tty): a local human can still tap the sensor to unlock, bounded by the timeout.
This is the path that lets an agent trigger the fingerprint prompt.

Usage (called by bw-run.sh, not directly):
    touchid-race.py <swift_helper_path> <account> <timeout_seconds> [headless]

Contract:
    stdout : the master password, ONLY on a successful fingerprint (exit 0)
    stderr : human-readable progress lines
    exit 0 : fingerprint accepted; password written to stdout
    exit 10: a key was pressed; caller should prompt for the master password
    exit 11: no fingerprint (cancelled / timed out), or no terminal and headless
             unlock is disabled
    exit 1 : usage / internal error

The password is only ever written to stdout and is never logged.
"""

import os
import select
import subprocess
import sys

try:
    import termios
    import tty
except ImportError:  # non-Unix; Touch ID is macOS-only anyway
    termios = None
    tty = None


def eprint(msg):
    sys.stderr.write(msg + "\n")
    sys.stderr.flush()


def truthy(v):
    return str(v).strip().lower() in ("1", "true", "yes", "on")


def run_headless(helper, account, timeout):
    """No controlling terminal, but headless Touch ID is enabled: show the sheet
    with no keypress escape (a script/agent caller has no keyboard here; the
    human at the physical Mac taps the sensor). Bounded by `timeout`, which the
    swift helper enforces by invalidating the sheet. Same stdout/exit contract as
    the race path: password on stdout + exit 0 on success, else exit 11."""
    eprint("Touch ID: place your finger on the sensor to unlock the vault (no terminal here)...")
    proc = subprocess.run(
        ["swift", helper, "get", account, timeout],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode == 0 and proc.stdout:
        eprint("  -> Touch ID accepted. Unlocking the vault (this can take a few seconds)...")
        sys.stdout.buffer.write(proc.stdout)
        sys.stdout.flush()
        return 0
    eprint("  -> no fingerprint (cancelled or timed out): falling back to the master password.")
    return 11


def main():
    if len(sys.argv) < 4:
        eprint("usage: touchid-race.py <swift_helper> <account> <timeout> [headless]")
        return 1
    helper, account, timeout = sys.argv[1], sys.argv[2], sys.argv[3]
    headless = len(sys.argv) >= 5 and truthy(sys.argv[4])

    # The keypress escape needs a controlling terminal. Without one (a script or
    # coding agent invoking bw-run) there is no keyboard to press: either show a
    # bare Touch ID sheet (headless, opt-in) so a local human can still tap to
    # unlock, or bail and let the caller fall back to `bw unlock`.
    try:
        tty_fd = os.open("/dev/tty", os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        if headless:
            return run_headless(helper, account, timeout)
        return 11

    saved = None
    proc = None
    try:
        # cbreak + no echo, set BEFORE spawning swift: a keypress is then seen
        # immediately and does not echo. Order matters: if this ran after the slow
        # swift spawn, a key pressed in that window would be stuck in the canonical
        # line buffer (unreadable until a newline) and select would never see it.
        # Restored in `finally`, so the terminal never stays broken.
        if termios is not None:
            try:
                saved = termios.tcgetattr(tty_fd)
                tty.setcbreak(tty_fd)
                mode = termios.tcgetattr(tty_fd)
                mode[3] &= ~termios.ECHO  # lflags
                termios.tcsetattr(tty_fd, termios.TCSANOW, mode)
            except termios.error:
                saved = None

        eprint("Touch ID: place your finger on the sensor, or press any key to use the password...")

        proc = subprocess.Popen(
            ["swift", helper, "get", account, timeout],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )

        pw = b""
        while True:
            rlist, _, _ = select.select([proc.stdout, tty_fd], [], [], 1.0)

            if tty_fd in rlist:
                try:
                    os.read(tty_fd, 4096)  # consume the keystroke(s)
                except OSError:
                    pass
                proc.terminate()
                eprint("  -> switching to the master password.")
                return 10

            if proc.stdout in rlist:
                pw = proc.stdout.read()  # swift wrote the password then exited (or EOF)
                break

            if proc.poll() is not None:  # swift exited between select wakeups
                pw = proc.stdout.read()
                break

        rc = proc.wait()
        if rc == 0 and pw:
            eprint("  -> Touch ID accepted. Unlocking the vault (this can take a few seconds)...")
            sys.stdout.buffer.write(pw)
            sys.stdout.flush()
            return 0

        eprint("  -> no fingerprint (cancelled or timed out): using the master password.")
        return 11
    finally:
        if proc is not None and proc.poll() is None:
            try:
                proc.terminate()
            except Exception:
                pass
        if saved is not None:
            try:
                termios.tcsetattr(tty_fd, termios.TCSANOW, saved)
            except Exception:
                pass
        try:
            if termios is not None:
                termios.tcflush(tty_fd, termios.TCIFLUSH)  # drop any typed-ahead
        except Exception:
            pass
        os.close(tty_fd)


if __name__ == "__main__":
    sys.exit(main())
