#!/bin/bash -e

if [[ ${1} == ppa:* ]]; then
  launchPadUrl=$(echo "${1}" | sed -e "s/ppa:/ppa.launchpad.net//")
  if has-repository "${launchPadUrl}"; then
    echo "Repository ${1} already installed"
    exit 0
  fi
fi

install-package software-properties-common
install-package dirmngr
install-package apt-transport-https
install-package lsb-release
install-package ca-certificates

echo "Installing repository: ${1}"

add-apt-repository -y "${1}" 2>&1

update-packages
