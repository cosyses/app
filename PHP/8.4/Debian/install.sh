#!/bin/bash -e

# Debian uses the same packages (from packages.sury.org instead of the PPA) and paths as Ubuntu
phpVersion="8.4"
phpTypes="cli fpm"

source "${cosysesPath}/PHP/Ubuntu/install-base.sh"
