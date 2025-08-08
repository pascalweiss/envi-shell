# Envi Installation Tests

This directory contains Docker-based tests to verify that the envi installation process works correctly in a clean environment.

## Files

- **`Dockerfile`** - Creates Ubuntu 22.04 test environment with curl, git, zsh, and bash
- **`test_installation.sh`** - Main test script that runs the installation and validates it
- **`README.md`** - This documentation

## Usage

### Prerequisites
- Docker installed and running
- Internet connection (for downloading envi from GitHub)

### Run Tests

```bash
# From the test directory
./test_installation.sh
```

### What the test does

1. **Setup**: Creates clean Ubuntu container with test user
2. **Install**: Runs the standard envi installation command from README
3. **Validate**: Checks multiple aspects of the installation:
   - `.envi_rc` file exists and sets `ENVI_HOME`
   - envi directory structure is created
   - Configuration files are properly copied
   - Basic commands work
   - Submodules are cloned correctly
4. **Cleanup**: Removes test containers and images

### Test Coverage

The test validates:
- ✅ Installation script execution
- ✅ File and directory creation
- ✅ Environment variable setup
- ✅ Configuration file copying from defaults
- ✅ Basic command availability
- ✅ Submodule initialization
- ✅ Clean installation in minimal environment

### Expected Output

```
=== ENVI INSTALLATION TEST ===
Cleaning up previous test runs...
Building Docker test image...
Starting Docker container and testing installation...
Installing envi in container...
Testing envi installation...
=== Testing envi components ===
✓ .envi_rc file exists
✓ ENVI_HOME is set: /home/testuser/.envi
✓ envi directory exists
✓ enviinit script exists
✓ .envi_env exists
✓ .envi_locations exists
✓ .envi_shortcuts exists
✓ envi command available
✓ dotfiles submodule exists
=== All tests passed! ===
Cleaning up test container...
🎉 ENVI INSTALLATION TEST PASSED!
```

## Usage in CI/CD

This test can be integrated into CI/CD pipelines to ensure installation works before releases:

```yaml
test:
  script:
    - cd test
    - ./test_installation.sh
```