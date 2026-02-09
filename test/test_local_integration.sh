#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="envi-test"
CONTAINER_NAME="envi-test-container-$(date +%s)"

echo "=== ENVI LOCAL INTEGRATION TEST ==="

# Build test image if needed (using podman)
if ! podman image exists "$IMAGE_NAME"; then
    echo "Building Podman test image..."
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Start container
echo "Starting Podman container..."
podman run --name "$CONTAINER_NAME" -d "$IMAGE_NAME" sleep 7200

# Copy local project files to container
# Excluding .git to save time, unless strictly needed. run_setup.sh doesn't seem to strictly need it.
# We create ~/.envi directly.
echo "Copying local files to container..."
# Using tar to copy directory structure efficiently
tar -C "$ROOT_DIR" --exclude='.git' -cf - . | podman exec -i "$CONTAINER_NAME" tar -xf - -C /home/testuser

# Move files to .envi (since we tarred the root content into home)
podman exec "$CONTAINER_NAME" bash -c 'mkdir -p ~/.envi && mv * .[^.]* ~/.envi/ 2>/dev/null || true'
# The mv command above is a bit hacky to move hidden files too. 
# Better: tar extract directly into ~/.envi
# Let's redo the copy properly.

echo "Re-copying local files to container ~/.envi..."
podman exec "$CONTAINER_NAME" rm -rf /home/testuser/.envi
podman exec "$CONTAINER_NAME" mkdir -p /home/testuser/.envi
tar -C "$ROOT_DIR" --exclude='.git' -cf - . | podman exec -i "$CONTAINER_NAME" tar -xf - -C /home/testuser/.envi

# Run installation inside container
echo "Installing envi in container..."
podman exec "$CONTAINER_NAME" bash -c '
export HOME=/home/testuser
cd ~/.envi
echo "=== Running setup ==="
# Inputs for run_setup.sh
{
  echo n   # configure timezone
  echo y   # update package manager
  echo n   # install dependencies
  echo y   # install OS packages (ffmpeg should be here)
  echo y   # install Python packages (yt-dlp, whisper should be here)
  # oh-my-zsh always installed
  echo n   # replace gitconfig
  echo y   # replace tmux
} | ./setup/run_setup.sh
'

# Verify integration
echo "Verifying integration..."
podman exec "$CONTAINER_NAME" bash -c '
    export HOME=/home/testuser
    source ~/.envi_rc 2>/dev/null || true
    export PATH=$HOME/.envi/executables/bin:$PATH
    
    FAILED=0
    
    check_cmd() {
        if command -v "$1" >/dev/null 2>&1; then
            echo "✓ $1 is installed"
        else
            echo "✗ $1 is MISSING"
            FAILED=1
        fi
    }
    
    check_cmd ffmpeg
    check_cmd yt-dlp
    check_cmd whisper
    check_cmd yt-to-txt
    
    # Check if yt-to-txt is executable
    if [ -x ~/.envi/executables/bin/yt-to-txt ]; then
        echo "✓ yt-to-txt is executable"
    else
        echo "✗ yt-to-txt is NOT executable"
        FAILED=1
    fi

    # Check symlinks point to valid targets
    check_symlink() {
        local link="$1"
        if [ -L "$link" ]; then
            if [ -e "$link" ]; then
                echo "✓ $link symlink OK"
            else
                echo "✗ $link symlink BROKEN (target does not exist)"
                FAILED=1
            fi
        else
            echo "✗ $link is not a symlink"
            FAILED=1
        fi
    }

    check_symlink ~/.envi_rc
    check_symlink ~/.envi_env
    check_symlink ~/.envi_locations
    check_symlink ~/.envi_shortcuts

    if [ $FAILED -eq 0 ]; then
        echo "ALL CHECKS PASSED"
        exit 0
    else
        echo "CHECKS FAILED"
        exit 1
    fi
'

TEST_RESULT=$?

# Cleanup
echo "Cleaning up..."
podman rm -f "$CONTAINER_NAME"

exit $TEST_RESULT
