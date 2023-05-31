#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

latestVersion=$(get-latest-package-version "${packageName}" "${baseVersion}")
installedVersion=$(get-installed-package-version "${packageName}")

if [[ -z "${latestVersion}" ]]; then
  echo "Could not find latest version of package: ${packageName}"
  echo "Possible candidates:"
  echo get-available-package-versions "${packageName}" | tr " " "\n" | sort -rV | uniq
  exit 1
fi

if [[ "$latestVersion" == "$installedVersion" ]]; then
  echo "Latest package ${packageName}=${latestVersion} already installed"
else
  echo "Installing latest package ${packageName}=${latestVersion}"
  checkUnattendedUpgrades=$(which check-unattended-upgrades)
  if [[ -n "${checkUnattendedUpgrades}" ]]; then
    check-unattended-upgrades
  fi
  UCF_FORCE_CONFOLD=1 DEBIAN_FRONTEND=noninteractive apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages "${packageName}"="${latestVersion}" 2>&1
fi
