#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

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
  # Ubuntu 24.04 and later mark the system Python as externally managed (PEP 668)
  PIP_BREAK_SYSTEM_PACKAGES=1 pip install --force-reinstall "${packageName}==${latestVersion}"
fi
