#!/usr/bin/env bash

source "$DIR"/setup/_func_console_output.sh

INSTALLED_PACKAGES=""
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
    if is_linux; then
      if has_sudo; then
        echo -e "${BLUE}Update apt.${NC}"
        sudo apt update
      else
        echo -e "${BLUE}Update apt.${NC}"
        apt update
      fi
      if [ ! `command -v brew` ]; then brew_install; fi
      echo -e "${BLUE}Update brew.${NC}"
      brew update
    elif is_darwin; then
        if [ ! `command -v brew` ]; then brew_install; fi
        echo -e "${BLUE}Update brew.${NC}"
        brew update
    fi
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
    # Install system prerequisites for Linux  
    if is_linux; then
        echo -e "${BLUE}Installing Homebrew prerequisites on Linux...${NC}"
        if has_sudo; then
            sudo apt update
            sudo apt install -y build-essential curl git
        else
            apt update
            apt install -y build-essential curl git  
        fi
    fi
    
    echo -e "${BLUE}Installing Homebrew...${NC}"
    # Install Homebrew (same script works for macOS and Linux)
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    echo -e "${BLUE}Activating Homebrew for current shell...${NC}"
    # Activate Homebrew for current session only (enviinit handles permanent config)
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        echo -e "${GREEN}Homebrew activated from /home/linuxbrew/.linuxbrew/bin/brew${NC}"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo -e "${GREEN}Homebrew activated from /opt/homebrew/bin/brew${NC}"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
        echo -e "${GREEN}Homebrew activated from /usr/local/bin/brew${NC}"
    else
        echo -e "${RED}Warning: Homebrew installation may have failed - no brew binary found${NC}"
    fi
}

function check_installation () {
    P=${1}
    if [ "$INSTALLED_PACKAGES" = "" ]; then
        if is_linux || is_darwin; then
            INSTALLED_PACKAGES=$(brew list);
        fi
    fi
    if [ `command -v $P` ]; then return 1; 
    else
        installed=$(echo "${INSTALLED_PACKAGES[@]}" | grep -c '^$P$')
        return "$installed";
    fi
}

function exec_install () {
    local ERROR
    check_installation "${1}"
    INSTALLED=$?
    if [ $INSTALLED = 0 ]; then
        if is_linux || is_darwin; then
            echo -e "${BLUE}Install ${1}.${NC}"
            HOMEBREW_NO_AUTO_UPDATE=1 brew install "${1}"
            ERROR=$?
        fi
        install_error_print "${1}" "$ERROR"
    else 
        echo -e "${GREEN}Already installed: ${1}${NC}"
    fi
}

function install_all () {
    for P in "${@}"; do
        exec_install "${P}"
    done
}
