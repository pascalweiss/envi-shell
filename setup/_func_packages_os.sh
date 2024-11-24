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
      echo -e "${YELLOW}Install tzdata.${NC}"
      sudo apt install tzdata
    else
      echo -e "${YELLOW}Install tzdata.${NC}"
      apt install tzdata
    fi
  fi
}

function update_package_manager () {
    if is_linux; then
      if has_sudo; then
        echo -e "${YELLOW}Update apt.${NC}"
        sudo apt update
      else
        echo -e "${YELLOW}Update apt.${NC}"
        apt update
      fi
    elif is_darwin; then
        if [ ! `command -v brew` ]; then brew_install; fi
        echo -e "${YELLOW}Update brew.${NC}"
        brew update
    fi
}

function install_dependencies () {
    readarray PACKAGES < "$DIR/setup/dependencies.txt"
    print_packages "dependencies" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_packages () {
    readarray PACKAGES < "$DIR/defaults/packages_os.txt"
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_python () {
    PACKAGES=("python3" "python3-pip")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_oh_my_zsh () {
    PACKAGES=("zsh")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}


# --- private ---

function brew_install () {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> /Users/pascalprivate/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/pascalprivate/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    exec zsh
}

function check_installation () {
    P=$1
    if [ "$INSTALLED_PACKAGES" = "" ]; then
        if is_linux; then
            INSTALLED_PACKAGES=$( apt list --installed | grep -oP "^.*/" | sed 's/.$//')
        elif is_darwin; then
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
    check_installation "$1"
    INSTALLED=$?
    if [ $INSTALLED = 0 ]; then
        if is_linux; then
            if has_sudo; then
                echo -e "${YELLOW}Install $1.${NC}"
                sudo apt install -y "$1"
                ERROR=$?
            else
                echo -e "${YELLOW}Install $1.${NC}"
                set -x
                apt install -y "$1"
                ERROR=$?
            fi
        elif is_darwin; then
            echo -e "${YELLOW}Install $1.${NC}"
            HOMEBREW_NO_AUTO_UPDATE=1 brew install "$1"
            ERROR=$?
        fi
        install_error_print "$1" "$ERROR"
    else 
        echo -e "${GREEN}Already installed: $1${NC}"
    fi
}

function install_all () {
    for P in "$@"; do
        exec_install "$P"
    done
}
