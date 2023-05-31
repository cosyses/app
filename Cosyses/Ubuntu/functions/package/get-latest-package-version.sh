#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

versions=($(get-available-package-versions "${packageName}" "${baseVersion}"))

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
