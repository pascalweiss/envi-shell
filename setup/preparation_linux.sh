#!/usr/bin/env bash

function set_packages() {
    PACKAGES=("${PACKAGES_DEFAULT[@]}" "${PACKAGES_PYTHON[@]}")
}

function install_packages() {
    apt update
    apt install -y $PACKAGES
}

