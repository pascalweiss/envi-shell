#!/usr/bin/env python3

"""
Bitwarden Secret Agent — holds secrets in memory, serves via Unix domain socket.

ssh-agent-style daemon: secrets are resolved once from Bitwarden (a single
`bw unlock` with the master password), then held in process memory. Clients
connect via Unix domain socket to retrieve them. No secrets are written to disk.

This file is a verbatim port of the AgentFactory secret-agent — it is backend
agnostic. Only the resolution layer (in bw-run.sh) differs: 1Password's
`op read` (Touch ID) is replaced by `bw unlock` + `bw get` (master password).

Usage (normally called by bw-run.sh, not directly):
    # Start agent with secrets as JSON on stdin:
    echo '{"KEY":"val"}' | python3 secret-agent.py <socket_path> <pid_file> <ttl_seconds>

    # Query agent (client mode):
    python3 secret-agent.py --query <socket_path>

    # Stop agent:
    python3 secret-agent.py --stop <socket_path> <pid_file>

Protocol:
    Client connects to socket, agent sends a JSON object with all secrets
    and closes the connection. Simple, one-shot, no framing needed.

Security:
    - Socket file: chmod 600 (owner-only)
    - Secrets exist only in process memory
    - Agent auto-exits after TTL (default 1h)
    - Agent PID file allows clean shutdown

Trust boundary:
    The agent trusts all processes running as the same OS user. Any process
    with the same UID can connect to the Unix domain socket and read the
    secrets. This is the same trust model used by ssh-agent, gpg-agent,
    macOS Keychain, and 1Password's own `op` CLI.
"""

import json
import os
import signal
import socket
import sys
import time


def start_agent(sock_path: str, pid_file: str, ttl: int) -> None:
    """Start the agent daemon. Reads secrets from stdin as JSON."""
    secrets_json = sys.stdin.read().strip()
    if not secrets_json:
        print("Error: no secrets provided on stdin", file=sys.stderr)
        sys.exit(1)

    # Validate JSON
    try:
        secrets = json.loads(secrets_json)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON on stdin: {e}", file=sys.stderr)
        sys.exit(1)

    # Prepare the response bytes once (immutable after this point)
    response = json.dumps(secrets).encode("utf-8")

    # Clean up stale socket
    if os.path.exists(sock_path):
        os.unlink(sock_path)

    # Create Unix domain socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(sock_path)
    os.chmod(sock_path, 0o600)
    server.listen(5)
    server.settimeout(60)  # wake up periodically to check TTL

    # Daemonize: fork to background
    pid = os.fork()
    if pid > 0:
        # Parent: write child PID and exit
        with open(pid_file, "w") as f:
            f.write(str(pid))
        os.chmod(pid_file, 0o600)
        # Print to stdout so the calling script knows the agent started
        print(f"Agent started (PID {pid})")
        sys.exit(0)

    # Child: become session leader
    os.setsid()

    # Close inherited stdin/stdout/stderr
    devnull = os.open(os.devnull, os.O_RDWR)
    os.dup2(devnull, 0)
    os.dup2(devnull, 1)
    os.dup2(devnull, 2)
    os.close(devnull)

    # Set up clean shutdown
    def cleanup(signum=None, frame=None):
        try:
            server.close()
        except Exception:
            pass
        try:
            os.unlink(sock_path)
        except Exception:
            pass
        try:
            os.unlink(pid_file)
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    deadline = time.monotonic() + ttl

    # Serve loop
    while time.monotonic() < deadline:
        try:
            conn, _ = server.accept()
            try:
                conn.sendall(response)
            finally:
                conn.close()
        except socket.timeout:
            continue
        except OSError:
            break

    cleanup()


def query_agent(sock_path: str) -> None:
    """Connect to agent and print secrets as JSON to stdout."""
    if not os.path.exists(sock_path):
        print("Error: agent not running (socket not found)", file=sys.stderr)
        sys.exit(1)

    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        client.connect(sock_path)
    except ConnectionRefusedError:
        print("Error: agent not running (connection refused)", file=sys.stderr)
        sys.exit(1)

    data = b""
    while True:
        chunk = client.recv(4096)
        if not chunk:
            break
        data += chunk
    client.close()

    sys.stdout.write(data.decode("utf-8"))


def stop_agent(sock_path: str, pid_file: str) -> None:
    """Stop the agent daemon."""
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            print(f"Agent stopped (PID {pid})")
        except (ProcessLookupError, ValueError):
            print("Agent was not running")
        # Clean up files (agent cleanup might race, so be safe)
        for path in (pid_file, sock_path):
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
    else:
        print("Agent not running (no PID file)")
        if os.path.exists(sock_path):
            os.unlink(sock_path)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage:", file=sys.stderr)
        print("  Start: echo '{...}' | secret-agent.py <sock> <pid> <ttl>", file=sys.stderr)
        print("  Query: secret-agent.py --query <sock>", file=sys.stderr)
        print("  Stop:  secret-agent.py --stop <sock> <pid>", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == "--query":
        query_agent(sys.argv[2])
    elif sys.argv[1] == "--stop":
        stop_agent(sys.argv[2], sys.argv[3])
    else:
        sock_path = sys.argv[1]
        pid_file = sys.argv[2]
        ttl = int(sys.argv[3]) if len(sys.argv) > 3 else 3600
        start_agent(sock_path, pid_file, ttl)


if __name__ == "__main__":
    main()
