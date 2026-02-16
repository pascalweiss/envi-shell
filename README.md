# Envi Shell

A modular, cross-platform development environment that configures your shell with a single command. Envi sets up zsh with Oh-My-Zsh, tmux session management, custom commands, and tool integrations — designed for developers who work across multiple machines.

## Installation

**Requirements:** `curl`, `git`, and `zsh`

**Important:** Envi is designed for zsh. During installation, it will automatically install Oh-My-Zsh and configure zsh as your default shell.

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/pascalweiss/envi-shell/main/setup/install.sh)"
```

This clones the repository to `~/.envi` and runs an interactive setup where you choose what to install.

**Alternative (for contributors):** Fork the repo, clone it, and run `setup/install.sh` manually.

> **Note:** The installation requires root rights for system package installation. Review the setup scripts before running if you have concerns.

## How It Works

Envi hooks into your shell startup and loads a layered configuration system:

```
Shell startup (.zshrc)
  ↓
source ~/.envi_rc
  ↓
enviinit: Complete environment initialization
  ├── Load config/envi_env (variables like TMUX_ENABLED, SSH_AGENT_ENABLED, ENVI_TMUX_ONLY)
  ├── Load config/envi_locations and config/envi_shortcuts
  ├── Set PATH, colors, UTF-8 locale
  ├── Tool integrations (conditional based on ENVI_TMUX_ONLY)
  │   ├── Minimal mode (ENVI_TMUX_ONLY=true, outside tmux): Homebrew, SSH only
  │   └── Full mode (default or inside tmux): All tools including Oh-My-Zsh, Node, etc.
  └── Interactive features (SSH agent startup, tmux auto-start)
  ↓
Oh-My-Zsh framework loading (zsh only, full mode only)
  ↓
Powerlevel10k theme loading (if POWERLEVEL10K_ENABLED=true, zsh only)
```

All behavior is controlled through environment variables in your config files. No magic — just sourced shell scripts.

## Configuration

Envi uses a two-layer config system. Defaults ship with the repo, and your personal config overrides them:

| File | Purpose | Edit command | Default location |
|------|---------|--------------|------------------|
| `config/envi_env` | Feature flags, PATH extensions, POWERLEVEL10K_ENABLED | `environ` | `~/.envi/config/envi_env` |
| `config/envi_locations` | Directory shortcuts | `loc` | `~/.envi/config/envi_locations` |
| `config/envi_shortcuts` | Custom aliases and functions | `short` | `~/.envi/config/envi_shortcuts` |

**Note:** The `environ`, `loc`, and `short` aliases open files with your `$EDITOR` (defaults to vim if not set). You can change your editor by setting `export EDITOR=nano` or your preferred editor in your shell profile.

### Key Feature Flags

Set these in `config/envi_env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_ENABLED` | `false` | Auto-start tmux on shell launch |
| `TMUX_AUTO_ATTACH` | `false` | Attach to existing session instead of creating new |
| `ENVI_TMUX_ONLY` | `false` | Minimal init outside tmux, full init inside (faster startup, prevents double initialization in tmux panes) |
| `SSH_AGENT_ENABLED` | `true` | Auto-start SSH agent for interactive shells |
| `OHMYZSH_ENABLED` | `true` | Load Oh-My-Zsh framework (zsh only) |
| `POWERLEVEL10K_ENABLED` | `false` | Load Powerlevel10k theme (requires zsh and Oh-My-Zsh) |
| `ENVI_DEBUG` | `false` | Enable debug logging |

## Tmux Integration

Envi provides a custom tmux configuration with a status bar theme, pane borders showing git status, and session management tools.

### Session Chooser for SSH Connections

When connecting to a remote machine via SSH, you can automatically get a session chooser menu instead of starting a new tmux session. This is useful when reconnecting from mobile clients like Termius.

**How it works:** Set the environment variable `LC_IDENTIFICATION=tmux-menu` on the SSH client side. This passes through SSH's `AcceptEnv LC_*` and triggers the native tmux session chooser on connect.

**Setup in your SSH client:**
1. Add an environment variable: `LC_IDENTIFICATION` = `tmux-menu`
2. Connect via SSH
3. If existing tmux sessions are found, the chooser menu appears
4. If no sessions exist, a new session is created

**Tmux shortcuts:**
- `tt` — Session manager (native tmux tree view inside tmux, fzf-based outside)
- `tmux-help` — Quick reference for tmux key bindings
- `Ctrl+b w` — Native tmux session/window chooser (customized with color theme)

### Status Bar

The tmux status bar displays:
- **Left:** Session name, window index, pane index
- **Right:** Docker container count, Kubernetes context, hostname
- **Pane borders:** Current directory path and git branch with uncommitted changes indicator

## Commands

### System Commands

| Command | Description |
|---------|-------------|
| `renamenice [FILES...]` | Normalize filenames (lowercase, underscores, umlaut conversion) |
| `fake-server <port>` | Start a development HTTP server in Docker that logs all requests |
| `netinfo` | Display LAN IP, WAN IP, broadcast, and MAC address |
| `tmux-help` | Display tmux key binding reference |
| `tfzf` | Tmux session selector with fzf (attach/kill sessions) |
| `todo` | Simple todo list manager |

### Core Aliases (System)

These are hardcoded in enviinit and open your `$EDITOR` (defaults to vim):

| Alias | Expands to |
|-------|-----------|
| `envi` | `cd ~/.envi` |
| `environ` | `$EDITOR ~/.envi/config/envi_env` |
| `loc` | `$EDITOR ~/.envi/config/envi_locations` |
| `short` | `$EDITOR ~/.envi/config/envi_shortcuts` |

### Interactive Functions (from config/envi_shortcuts)

| Function | Description |
|----------|-------------|
| `tt` | Session manager - native tmux tree view inside tmux, fzf-based selector outside |
| `sshd <host>` | Smart SSH - detaches tmux before connecting to avoid nested sessions |
| `mkcd <dir>` | Create directory and navigate to it |
| `o <file>` | Open file (uses `open` on macOS, custom handler on Linux) |

### Additional Aliases (from config/envi_shortcuts)

| Alias | Purpose |
|-------|---------|
| `clr` | Clear screen |
| `execz` | Restart shell with `exec zsh` |
| `py3`, `ipy` | Python shortcuts |
| `pingg` | Ping to 1.1.1.1 with 0.2s interval |

## Tool Integrations

Envi automatically detects and configures the following tools when present:

| Tool | What Envi Does | Conditional? |
|------|----------------|--------------|
| **Homebrew** | Adds to PATH, sets up environment | Minimal mode (ENVI_TMUX_ONLY=true) runs this outside tmux |
| **Oh-My-Zsh** | Loads framework with configured plugins and theme | Full mode only (or inside tmux with ENVI_TMUX_ONLY=true) |
| **Powerlevel10k** | Loads Powerlevel10k theme (requires POWERLEVEL10K_ENABLED=true) | Full mode only |
| **Node.js / NVM** | Loads NVM if `~/.nvm/nvm.sh` exists | Full mode only |
| **Neovim** | Applies default configuration | Full mode only |
| **Git** | Sets up gitconfig | Minimal mode (ENVI_TMUX_ONLY=true) runs this outside tmux |
| **SSH** | Auto-starts SSH agent for interactive shells | Minimal mode (ENVI_TMUX_ONLY=true) runs this outside tmux |
| **tmux** | Auto-start, custom theme, session management | Full mode only |
| **Angular** | CLI autocompletion | Full mode only |
| **Flux** | CLI autocompletion | Full mode only |

**Note:** The "Conditional?" column indicates which tools respect the `ENVI_TMUX_ONLY` optimization flag. When enabled, minimal tools run outside tmux for faster startup, while full tools only run inside tmux or when ENVI_TMUX_ONLY is false.

## Project Structure

```
~/.envi/
├── setup/                        Interactive installation system
│   └── install.sh                Main installation script
├── executables/
│   ├── bin/                      Universal commands (all platforms)
│   ├── linuxbin/                 Linux-specific commands
│   ├── macbin/                   macOS-specific commands
│   └── sbin/
│       └── enviinit              Core initialization script (sourced at shell startup)
├── defaults/
│   ├── default_env_user.sh       Default feature flags and environment variables
│   ├── default_locations.sh      Default directory shortcuts
│   ├── default_shortcuts.sh      Default aliases and functions
│   └── packages_os.txt           OS packages installed during setup
├── config/                       User configurations (override defaults)
│   ├── envi_env                  User feature flags and environment variables
│   ├── envi_locations            User directory shortcuts
│   └── envi_shortcuts            User aliases and functions
├── tool-integrations/            Modular initialization scripts per tool
│   ├── angular/                  Angular CLI setup
│   ├── flux/                     Flux CLI setup
│   ├── git/                      Git configuration
│   ├── homebrew/                 Homebrew setup
│   ├── neovim/                   Neovim configuration
│   ├── node/                     Node.js/NVM setup
│   ├── ssh/                      SSH agent setup
│   ├── tmux/                     Tmux configuration and theme
│   └── zsh/                      Zsh configuration and themes
└── test/                         Docker-based installation tests
```

## Testing

Envi includes Docker-based tests to verify installation across platforms:

```bash
# Run installation verification tests
./test/test_installation.sh

# Run local integration tests
./test/test_local_integration.sh
```

## License

MIT
