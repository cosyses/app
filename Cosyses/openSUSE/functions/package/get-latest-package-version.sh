#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

latestVersion=$(get-available-package-versions "${packageName}" "${baseVersion}" | head -n 1)

if [[ -z "${latestVersion}" ]]; then
  >&2 echo "Could not find latest version for package: ${packageName} in version: ${baseVersion}"
  exit 1
fi

echo "${latestVersion}"
