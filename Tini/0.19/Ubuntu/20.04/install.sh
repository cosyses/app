#!/bin/bash -e

echo "Installing Tini"
wget -nv https://github.com/krallin/tini/releases/download/v0.19.0/tini -O /usr/local/bin/tini
chmod +x /usr/local/bin/tini
