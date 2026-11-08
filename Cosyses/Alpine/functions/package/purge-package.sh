#!/bin/bash -e

packageName="${1}"

if [[ -n "$(get-installed-package-version "${packageName}")" ]]; then
  echo "Removing package: ${packageName}"
  apk del --no-interactive "${packageName}" 2>&1
else
  echo "Package ${packageName} not installed"
fi
