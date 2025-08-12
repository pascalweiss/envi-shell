# Repository Guidelines

## Project Structure & Module Organization
- `executables/`: CLI entrypoints and helpers. Use `bin/` for cross-platform tools, `linuxbin/` or `macbin/` for OS-specific, and `sbin/` for system init like `executables/sbin/enviinit`.
- `setup/`: Installation automation (`run_setup.sh`, `_func_*.sh`). Scripts are sourced by the installer.
- `defaults/`: Baseline config loaded first (env, locations, shortcuts, neovim). User overrides live in `config/`.
- `config/`: User-editable copies (`.envi_env`, `.envi_locations`, `.envi_shortcuts`, `.envi_rc`).
- `tool-integrations/`: Self-contained init for tools (homebrew, zsh, neovim, node, tmux, etc.).
- `test/`: Docker-based smoke tests (`test_installation.sh`).

## Build, Test, and Development Commands
- Run setup locally: `bash setup/run_setup.sh` — interactive installer, links configs, installs shells/tools.
- Install from remote: `sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"`
- Run tests: `bash test/test_installation.sh` — builds Docker image and verifies install, aliases, and tmux. Requires Docker.
- Lint shell scripts (recommended): `shellcheck path/to/script.sh`

## Coding Style & Naming Conventions
- Language: Bash (`#!/usr/bin/env bash`). Prefer POSIX-compatible where practical; use Bash features when needed.
- Indentation: 4 spaces; no tabs. Quote variables defensively.
- Functions: lower_snake_case; keep small and composable (e.g., `add_symlink`, `contains`).
- Files: lower_snake_case for helpers (`_func_*.sh`, `default_*.sh`); executables without extension in `executables/{bin,linuxbin,macbin}` and marked executable (`chmod +x`).
- Sourcing order: defaults → user config → tool integrations (see `enviinit`).

## Testing Guidelines
- Framework: Bash + Docker. Add tests under `test/` as `test_*.sh`.
- Scope: Validate `enviinit`, symlinks, required aliases, and tool availability on Linux/macOS.
- Run locally: `bash test/test_installation.sh`. Ensure tests are non-interactive and fail fast (`set -e`).

## Commit & Pull Request Guidelines
- Commits: Short, descriptive, imperative (e.g., “Add tmux auto-detection”, “Fix macOS init errors”). Group related changes.
- PRs: Include summary, rationale, affected platforms (Linux/macOS), test evidence (logs or screenshots), and breaking-change notes. Link issues when applicable.

## Security & Configuration Tips
- Do not commit secrets. Keep user-specific changes in `config/` only.
- Be cautious modifying shell startup flow; keep interactive features out of `enviinit` and in post-init where applicable.

## Agent-Specific Instructions
- Commit authorship: Do not add co-authors. Never include `Co-authored-by:` trailers; commit messages must attribute only the human author initiating the commit.
