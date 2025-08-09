#!/usr/bin/env bash

# Envi Installation Test Script
# This script tests the envi installation process in a clean Docker environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="envi-test"
CONTAINER_NAME="envi-test-container-$(date +%s)"

echo "=== ENVI INSTALLATION TEST ==="

# Clean up any existing containers/images
echo "Cleaning up previous test runs..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker rmi "$IMAGE_NAME" 2>/dev/null || true

# Build test image
echo "Building Docker test image..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

# Run installation test
echo "Starting Docker container and testing installation..."
docker run --name "$CONTAINER_NAME" -d "$IMAGE_NAME" sleep 7200

# Execute installation inside container
echo "Installing envi in container..."
docker exec "$CONTAINER_NAME" bash -c '
echo "=== Installing envi ==="
{
  echo n   # configure timezone
  echo y   # update package manager (installs Homebrew)
  echo n   # install dependencies
  echo y   # install OS packages via Homebrew (includes tmux)
  echo n   # install Python packages
  echo y   # install oh-my-zsh
  echo y   # replace zshrc
  echo n   # replace bashrc
  echo n   # replace vim
  echo n   # replace gitconfig
  echo y   # replace tmux
  echo ""  # empty password for chsh
  echo ""  # second empty password attempt if needed
} | sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"
'

# Test installation
echo "Testing envi installation..."
docker exec "$CONTAINER_NAME" bash -c '
    echo "=== Testing envi components ==="
    
    # Initialize failure tracking
    FAILED_TESTS=0
    
    # Test 1: Check if .envi_rc exists
    if [ -f ~/.envi_rc ]; then
        echo "✓ .envi_rc file exists"
    else
        echo "✗ .envi_rc file missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 2: Source envi and check ENVI_HOME
    source ~/.envi_rc 2>/dev/null || true
    if [ -n "$ENVI_HOME" ]; then
        echo "✓ ENVI_HOME is set: $ENVI_HOME"
    else
        echo "✗ ENVI_HOME not set"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 3: Check if envi directory exists
    if [ -d ~/.envi ]; then
        echo "✓ envi directory exists"
    else
        echo "✗ envi directory missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 4: Check if enviinit script exists
    if [ -f ~/.envi/executables/sbin/enviinit ]; then
        echo "✓ enviinit script exists"
    else
        echo "✗ enviinit script missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 5: Check if config files were created
    for config in .envi_env .envi_locations .envi_shortcuts; do
        if [ -f ~/.envi/config/$config ]; then
            echo "✓ $config exists"
        else
            echo "✗ $config missing"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
    
    # Test 6: Test envi alias is available
    source ~/.envi_rc 2>/dev/null || true
    if alias envi >/dev/null 2>&1; then
        echo "✓ envi alias available"
    else
        echo "✗ envi alias not available"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 7: Test submodules exist
    if [ -d ~/.envi/submodules/dotfiles ]; then
        echo "✓ dotfiles submodule exists"
    else
        echo "✗ dotfiles submodule missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 8: Test tmux configuration exists
    if [ -f ~/.tmux.conf ]; then
        echo "✓ tmux configuration exists"
    else
        echo "✗ tmux configuration missing"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 9: Test tmux configuration is valid
    if tmux source-file ~/.tmux.conf 2>/dev/null; then
        echo "✓ tmux configuration is valid"
    else
        echo "✗ tmux configuration is invalid"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Test 10: Test Homebrew packages are installed
    echo "=== Testing Homebrew packages ==="
    source ~/.envi_rc 2>/dev/null || true
    
    # Test packages with their actual command names
    declare -A PACKAGES=(
        ["jq"]="jq"
        ["yq"]="yq" 
        ["vim"]="vim"
        ["neovim"]="nvim"
        ["sl"]="sl"
        ["htop"]="htop"
        ["bat"]="bat"
        ["fzf"]="fzf"
        ["eza"]="eza"
        ["tmux"]="tmux"
    )
    
    for pkg_name in "${!PACKAGES[@]}"; do
        cmd_name="${PACKAGES[$pkg_name]}"
        if command -v "$cmd_name" >/dev/null 2>&1; then
            echo "✓ $pkg_name is available (as $cmd_name)"
        else
            echo "✗ $pkg_name is not available (expected command: $cmd_name)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    done
    
    # Test 11: Test brew command is available
    if command -v brew >/dev/null 2>&1; then
        echo "✓ brew command is available"
    else
        echo "✗ brew command is not available"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Final result
    echo "=== Test Summary ==="
    if [ $FAILED_TESTS -eq 0 ]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ $FAILED_TESTS test(s) failed!"
        exit 1
    fi
'

TEST_RESULT=$?

# Clean up
echo "Cleaning up test container..."
docker rm -f "$CONTAINER_NAME"
docker rmi "$IMAGE_NAME"

if [ $TEST_RESULT -eq 0 ]; then
    echo "🎉 ENVI INSTALLATION TEST PASSED!"
    exit 0
else
    echo "❌ ENVI INSTALLATION TEST FAILED!"
    exit 1
fi