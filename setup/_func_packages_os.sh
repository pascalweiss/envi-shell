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

function install_curl () {
    if [[ "$SYSTEM_NAME" == "Linux" ]]; then
      if has_sudo; then
        sudo apt update
        sudo apt install -y curl
      else
        apt update
        apt install -y curl
      fi
    fi
}

function update_package_manager () {
    if is_linux; then
      if has_sudo; then
        sudo apt update
      else
        apt update
      fi
    elif is_darwin; then
        if [ ! `command -v brew` ]; then brew_install; fi
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
        if [[ "$SYSTEM_NAME" = *Linux* ]]; then 
            INSTALLED_PACKAGES=$( apt list --installed | grep -oP "^.*/" | sed 's/.$//')
        elif [[ "$SYSTEM_NAME" = *Darwin* ]]; then INSTALLED_PACKAGES=$(brew list);
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
        if [ -f "/proc/version" ]; then
            if has_sudo; then
                sudo apt install -y "$1"
                ERROR=$?
            else
                apt install -y "$1"
                ERROR=$?
            fi
        elif [ -d "/System" ]; then
            HOMEBREW_NO_AUTO_UPDATE=1 brew install "$1"
            ERROR=$?
        fi
        install_error_print "$1" "$ERROR"
    else 
        echo "Already installed: $1"
    fi
}

function install_all () {
    for P in "$@"; do
        exec_install "$P"
    done
}
