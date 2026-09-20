#!/bin/bash -e

packageName="${1}"
baseVersion="${3}"

latestVersion=$(get-latest-pip-package-version "${packageName}" "${baseVersion}")
installedVersion=$(get-installed-pip-package-version "${packageName}")

if [[ -z "${latestVersion}" ]]; then
  echo "Could not find latest version of pip package: ${packageName}"
  echo "Possible candidates:"
  echo get-available-pip-package-versions "${packageName}" | tr " " "\n" | sort -rV | uniq
  exit 1
fi

if [[ "${latestVersion}" == "${installedVersion}" ]]; then
  echo "Latest pip package ${packageName}=${latestVersion} already installed"
else
  echo "Installing pip package ${packageName}=${latestVersion}"
  pip install --force-reinstall "${packageName}==${latestVersion}"
fi
