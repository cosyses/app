#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

# zypper search prints a table: S | Name | Type | Version | Arch | Repository
zypper --non-interactive --quiet search --details --match-exact --type package "${packageName}" 2>/dev/null | awk -F'|' -v packageName="${packageName}" -v baseVersion="${baseVersion}" '{
  name = $2; version = $4
  gsub(/^[ \t]+|[ \t]+$/, "", name)
  gsub(/^[ \t]+|[ \t]+$/, "", version)
  if (name == packageName && version ~ /^[0-9]/ && (baseVersion == "" || index(version, baseVersion) == 1)) {
    print version
  }
}' | sort -rV | uniq
