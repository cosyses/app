#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

if ! latestVersion=$(get-latest-package-version "${packageName}" "${baseVersion}"); then
  echo "Could not find latest version of package: ${packageName}"
  echo "Possible candidates:"
  get-available-package-versions "${packageName}"
  exit 1
fi
installedVersion=$(get-installed-package-version "${packageName}")

if [[ "${latestVersion}" == "${installedVersion}" ]]; then
  echo "Latest package ${packageName}=${latestVersion} already installed"
else
  echo "Installing latest package ${packageName}=${latestVersion}"
  # --oldpackage allows a version below the installed one
  zypper --non-interactive install --oldpackage --force-resolution "${packageName}=${latestVersion}" 2>&1
fi
