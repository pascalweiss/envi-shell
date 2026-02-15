# Envi Shell

A modular, cross-platform development environment that configures your shell with a single command. Envi sets up zsh with Oh-My-Zsh, tmux session management, custom commands, and tool integrations — designed for developers who work across multiple machines.

## Installation

**Requirements:** `curl` and `git`

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
  └── source ~/.envi_rc
        └── enviinit
              ├── Load defaults, then user config (user overrides defaults)
              ├── Set PATH, colors, locale
              ├── Tool integrations (homebrew, node, neovim, etc.)
              └── Interactive features (tmux auto-start, SSH agent)
```

All behavior is controlled through environment variables in your config files. No magic — just sourced shell scripts.

## Configuration

Envi uses a two-layer config system. Defaults ship with the repo, and your personal config overrides them:

| File | Purpose | Edit command |
|------|---------|--------------|
| `config/envi_env` | Feature flags, PATH extensions | `environ` |
| `config/envi_locations` | Directory shortcuts | `loc` |
| `config/envi_shortcuts` | Custom aliases and functions | `short` |

### Key Feature Flags

Set these in `config/envi_env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_ENABLED` | `false` | Auto-start tmux on shell launch |
| `TMUX_AUTO_ATTACH` | `false` | Attach to existing session instead of creating new |
| `ENVI_TMUX_ONLY` | `false` | Minimal init outside tmux, full init inside (faster startup) |
| `SSH_AGENT_ENABLED` | `true` | Auto-start SSH agent for interactive shells |
| `OHMYZSH_ENABLED` | `true` | Load Oh-My-Zsh framework |
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

### Universal Commands

| Command | Description |
|---------|-------------|
| `git whoami` | Show current git user and email |
| `renamenice [FILES...]` | Normalize filenames (lowercase, underscores, umlaut conversion) |
| `fake-server <port>` | Start a development HTTP server in Docker that logs all requests |
| `netinfo` | Display LAN IP, WAN IP, broadcast, and MAC address |
| `tt` | Interactive tmux session manager |
| `tmux-help` | Display tmux key binding reference |
| `tfzf` | Tmux session selector with fzf (attach/kill sessions) |

### Built-in Aliases

| Alias | Expands to | Notes |
|-------|-----------|-------|
| `envi` | `cd ~/.envi` | Navigate to envi directory |
| `environ` | `vim ~/.envi/config/envi_env` | Edit environment config |
| `loc` | `vim ~/.envi/config/envi_locations` | Edit location shortcuts |
| `short` | `vim ~/.envi/config/envi_shortcuts` | Edit custom shortcuts |
| `clr` | `clear` | |
| `execz` | `exec zsh` | Restart shell |
| `mkcd <dir>` | `mkdir -p && cd` | Create directory and enter it |
| `o <file>` | `open` | Open file (cross-platform) |
| `sshd <host>` | Smart SSH | Detaches tmux before connecting |

## Tool Integrations

Envi automatically detects and configures the following tools when present:

| Tool | What Envi Does |
|------|---------------|
| **Homebrew** | Adds to PATH, sets up environment |
| **Oh-My-Zsh** | Loads framework with configured plugins and theme |
| **Node.js / NVM** | Loads NVM if `~/.nvm/nvm.sh` exists |
| **Neovim** | Applies default configuration |
| **Git** | Sets up gitconfig |
| **SSH** | Auto-starts SSH agent for interactive shells |
| **tmux** | Auto-start, custom theme, session management |
| **Angular** | CLI autocompletion |
| **Flux** | CLI autocompletion |

## Project Structure

```
~/.envi/
├── setup/                  Interactive installation system
├── executables/
│   ├── bin/                Universal commands (all platforms)
│   ├── linuxbin/           Linux-specific commands
│   ├── macbin/             macOS-specific commands
│   └── sbin/enviinit       Core initialization script
├── defaults/               Default configurations (templates)
├── config/                 User configurations (editable, override defaults)
├── tool-integrations/      Modular init scripts per tool
│   ├── tmux/               Tmux config and initialization
│   ├── zsh/                Zsh config and themes
│   ├── homebrew/           Homebrew setup
│   ├── node/               Node.js/NVM setup
│   └── ...                 Other tool integrations
└── test/                   Docker-based installation tests
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
