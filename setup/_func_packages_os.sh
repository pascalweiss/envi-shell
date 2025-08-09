#!/usr/bin/env bash

source "$DIR"/setup/_func_console_output.sh

SYSTEM_NAME=$(uname)


# Function to check if the user is root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Function to check if sudo is available
has_sudo() {
    command -v sudo >/dev/null 2>&1
}

is_linux() {
    [[ "$SYSTEM_NAME" == "Linux" ]]
}

is_darwin() {
    [[ "$SYSTEM_NAME" == "Darwin" ]]
}

configure_timezone() {
  if is_linux; then
    if has_sudo; then
      echo -e "${BLUE}Install tzdata.${NC}"
      sudo apt install tzdata
    else
      echo -e "${BLUE}Install tzdata.${NC}"
      apt install tzdata
    fi
  fi
}

function update_package_manager () {
    # Install/update apt only on Linux (for system prerequisites)
    if is_linux; then
      if has_sudo; then
        echo -e "${BLUE}Update apt.${NC}"
        sudo apt update
      else
        echo -e "${BLUE}Update apt.${NC}"
        apt update
      fi
    fi
    
    # Install/update Homebrew (unified for all platforms)
    if ! command -v brew >/dev/null 2>&1; then brew_install; fi
    echo -e "${BLUE}Update brew.${NC}"
    brew update
}

function install_dependencies () {
    local PACKAGES=();
    while IFS= read -r line; do
        PACKAGES+=("$line")
    done < "$DIR/setup/dependencies.txt"
    print_packages "dependencies" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_packages () {
    readarray -t PACKAGES < "$DIR/defaults/packages_os_brew.txt" # read Homebrew packages
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_python () {
    PACKAGES=("python3" "pipx")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
    echo -e "${BLUE}Ensure path for pipx with 'pipx ensurepath'${NC}"
    pipx ensurepath
}

function install_oh_my_zsh () {
    PACKAGES=("zsh")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}


# --- private ---

function brew_install () {
    # Install system prerequisites for Linux (skip apt update - already done by caller)
    if is_linux; then
        echo -e "${BLUE}Installing Homebrew prerequisites on Linux...${NC}"
        if has_sudo; then
            sudo apt install -y build-essential curl git
        else
            apt install -y build-essential curl git  
        fi
    fi
    
    echo -e "${BLUE}Installing Homebrew...${NC}"
    # Install Homebrew (same script works for macOS and Linux)
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Activate Homebrew for current session only (enviinit handles permanent config)
    for brew_path in "/home/linuxbrew/.linuxbrew/bin/brew" "/opt/homebrew/bin/brew" "/usr/local/bin/brew"; do
        if [ -x "$brew_path" ]; then
            eval "$($brew_path shellenv)"
            echo -e "${GREEN}Homebrew activated${NC}"
            return
        fi
    done
    echo -e "${RED}Warning: Homebrew installation may have failed${NC}"
}

function check_installation () {
    # Check if package is already installed via command availability
    if command -v "${1}" >/dev/null 2>&1; then
        return 1  # Already installed
    else
        return 0  # Not installed
    fi
}

function exec_install () {
    check_installation "${1}"
    if [ $? = 0 ]; then
        echo -e "${BLUE}Install ${1}.${NC}"
        HOMEBREW_NO_AUTO_UPDATE=1 brew install "${1}"
        install_error_print "${1}" "$?"
    else 
        echo -e "${GREEN}Already installed: ${1}${NC}"
    fi
}

function install_all () {
    for P in "${@}"; do
        exec_install "${P}"
    done
}
