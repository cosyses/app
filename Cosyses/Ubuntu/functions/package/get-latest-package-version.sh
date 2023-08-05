#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

versions=($(get-available-package-versions "${packageName}" "${baseVersion}"))

if [[ "${#versions}" -eq 0 ]]; then
  >&2 echo "Could not find latest version for package: ${packageName} in version: ${baseVersion}"
  exit 1
fi

comparableVersions=()
declare -A originalVersions
for version in "${versions[@]}"; do
  comparableVersion=$(echo "${version}" | sed 's/^[0-9]://')
  comparableVersions+=("${comparableVersion}")
  originalVersions["${comparableVersion}"]="${version}"
done

sortedVersions=($(echo "${comparableVersions[@]}" | tr " " "\n" | sed 's/^[0-9]://' | sort -rV))
latestVersion="${sortedVersions[0]}"

echo "${originalVersions[${latestVersion}]}"
