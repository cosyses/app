#!/bin/bash -e

packageName="${1}"

if [[ -n "$(get-installed-package-version "${packageName}")" ]]; then
  echo "Removing package: ${packageName}"
  zypper --non-interactive remove --clean-deps "${packageName}" 2>&1
else
  echo "Package ${packageName} is not installed"
fi
