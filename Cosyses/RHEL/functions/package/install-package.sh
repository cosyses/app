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
elif [[ -n "${installedVersion}" ]] && [[ $(printf '%s\n' "${latestVersion}" "${installedVersion}" | sort -V | head -n 1) == "${latestVersion}" ]]; then
  echo "Downgrading package ${packageName} to ${latestVersion}"
  dnf downgrade -y "${packageName}-${latestVersion}" 2>&1
else
  echo "Installing latest package ${packageName}=${latestVersion}"
  # Allows replacing a conflicting package, e.g. coreutils-single or curl-minimal of the minimal images
  dnf install -y --allowerasing "${packageName}-${latestVersion}" 2>&1
fi
