# Envi Installation Tests

This directory contains container-based tests to verify that the envi installation process works correctly in a clean environment.

## Files

- **`Dockerfile`** - Creates Ubuntu 22.04 test environment with curl, git, zsh, and bash
- **`test_installation.sh`** - Tests installation from GitHub (remote)
- **`test_local_integration.sh`** - Tests installation from local codebase
- **`README.md`** - This documentation

## Usage

### Prerequisites
- Docker or Podman installed and running
- Internet connection (for downloading dependencies)

### Run Tests

**Test remote installation (from GitHub):**
```bash
# Requires Docker
cd test
./test_installation.sh
```

**Test local installation (current codebase):**
```bash
# Requires Podman
cd test
./test_local_integration.sh
```

Or from the repository root:
```bash
./test/test_local_integration.sh
```

### What the tests do

**test_installation.sh (Remote):**
1. **Setup**: Creates clean Ubuntu container with test user
2. **Install**: Runs the standard envi installation command from GitHub
3. **Validate**: Checks multiple aspects of the installation:
   - `.envi_rc` file exists and sets `ENVI_HOME`
   - envi directory structure is created
   - Configuration files are properly copied (without leading dots in config/)
   - Basic commands work
   - Submodules are cloned correctly
4. **Cleanup**: Removes test containers and images

**test_local_integration.sh (Local):**
1. **Setup**: Creates clean Ubuntu container and copies local repository
2. **Install**: Runs `setup/run_setup.sh` with the local codebase
3. **Validate**: Checks tool integrations (ffmpeg, yt-dlp, whisper, custom tools)
4. **Cleanup**: Removes test container

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
✓ envi_env exists
✓ envi_locations exists
✓ envi_shortcuts exists
✓ envi command available
✓ dotfiles submodule exists
=== All tests passed! ===
Cleaning up test container...
🎉 ENVI INSTALLATION TEST PASSED!
```

## Container Runtime Notes

- **test_installation.sh** uses Docker and tests the remote installation from GitHub
- **test_local_integration.sh** uses Podman and tests the local codebase
- Both can be adapted to use either runtime by changing the container commands

## Usage in CI/CD

These tests can be integrated into CI/CD pipelines to ensure installation works before releases:

```yaml
test:
  script:
    - cd test
    - ./test_installation.sh  # Test remote installation
    - ./test_local_integration.sh  # Test local changes
```