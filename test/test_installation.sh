#!/usr/bin/env bash

# Envi Installation Test Script
# This script tests the envi installation process in a clean Docker environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="envi-test"
CONTAINER_NAME="envi-test-container"

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
docker run --name "$CONTAINER_NAME" -d "$IMAGE_NAME" sleep 3600

# Execute installation inside container
echo "Installing envi in container..."
docker exec "$CONTAINER_NAME" bash -c '
    echo "=== Installing envi ==="
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)" << EOF
n
n
n
n
n
y
y
n
n
n
EOF
'

# Test installation
echo "Testing envi installation..."
docker exec "$CONTAINER_NAME" bash -c '
    echo "=== Testing envi components ==="
    
    # Test 1: Check if .envi_rc exists and is sourced
    if [ -f ~/.envi_rc ]; then
        echo "✓ .envi_rc file exists"
    else
        echo "✗ .envi_rc file missing"
        exit 1
    fi
    
    # Test 2: Source envi and check ENVI_HOME
    source ~/.envi_rc
    if [ -n "$ENVI_HOME" ]; then
        echo "✓ ENVI_HOME is set: $ENVI_HOME"
    else
        echo "✗ ENVI_HOME not set"
        exit 1
    fi
    
    # Test 3: Check if envi directory exists
    if [ -d ~/.envi ]; then
        echo "✓ envi directory exists"
    else
        echo "✗ envi directory missing"
        exit 1
    fi
    
    # Test 4: Check if enviinit script exists
    if [ -f ~/.envi/executables/sbin/enviinit ]; then
        echo "✓ enviinit script exists"
    else
        echo "✗ enviinit script missing"
        exit 1
    fi
    
    # Test 5: Check if config files were created
    for config in .envi_env .envi_locations .envi_shortcuts; do
        if [ -f ~/.envi/config/$config ]; then
            echo "✓ $config exists"
        else
            echo "✗ $config missing"
            exit 1
        fi
    done
    
    # Test 6: Test basic envi command
    if command -v envi >/dev/null 2>&1; then
        echo "✓ envi command available"
    else
        echo "✗ envi command not available"
        exit 1
    fi
    
    # Test 7: Test submodules exist
    if [ -d ~/.envi/submodules/dotfiles ]; then
        echo "✓ dotfiles submodule exists"
    else
        echo "✗ dotfiles submodule missing"
        exit 1
    fi
    
    echo "=== All tests passed! ==="
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