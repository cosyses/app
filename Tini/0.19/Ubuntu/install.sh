#!/bin/bash -e

echo "Installing Tini"
if [[ -n "$(get-available-package-versions tini 0.19)" ]]; then
  install-package tini 0.19
else
  wget -nv https://github.com/krallin/tini/releases/download/v0.19.0/tini -O /usr/local/bin/tini 2>&1
  chmod +x /usr/local/bin/tini
fi
