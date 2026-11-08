#!/bin/bash -e

packageName="${1}"
baseVersion="${2}"

# apk policy lists every available version of the package as an indented line ending with a colon
apk policy "${packageName}" 2>/dev/null | awk -v baseVersion="${baseVersion}" '/^  [^ ].*:$/ {
  version = substr($0, 3, length($0) - 3)
  if (baseVersion == "" || index(version, baseVersion) == 1) {
    print version
  }
}' | sort -rV | uniq
