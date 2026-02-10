#!/bin/bash -e

echo "Installing Tini"
wget -nv https://github.com/krallin/tini/releases/download/v0.19.0/tini -O /usr/local/bin/tini 2>&1
chmod +x /usr/local/bin/tini
