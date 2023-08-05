#!/bin/bash -e

packageName="${1}"

installedVersion=$(get-installed-package-version "${packageName}")

if [[ -z "${installedVersion}" ]]; then
  echo "Package ${packageName} is not installed"
else
  apt-get remove --purge "${packageName}" -y
fi
