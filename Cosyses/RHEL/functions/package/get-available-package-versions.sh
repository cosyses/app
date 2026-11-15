#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

# Every available version of the package as <version>-<release>, the newest first
dnf -q repoquery --queryformat "%{version}-%{release}\n" "${packageName}" 2>/dev/null | awk -v baseVersion="${baseVersion}" 'NF > 0 {
  if (baseVersion == "" || index($0, baseVersion) == 1) {
    print $0
  }
}' | sort -rV | uniq
