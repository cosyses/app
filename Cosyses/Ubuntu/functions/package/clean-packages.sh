#!/bin/bash -e

obsoletePackages=( $(apt-get --dry-run autoremove | grep -Po '^Remv \K[^ ]+' | cat) )

if [[ "${#obsoletePackages[@]}" -gt 0 ]]; then
  echo "Removing obsolete packages"
  apt-get autoremove --purge -y
else
  echo "No packages to clean"
fi
