#!/bin/bash -e

packageName="${1}"

# apk list prints: <name>-<version> <architecture> {<origin>} (<license>) [installed]
apk list --installed "${packageName}" 2>/dev/null | awk -v packageName="${packageName}" '{
  prefix = packageName "-"
  if (index($1, prefix) == 1 && substr($1, length(prefix) + 1) ~ /^[0-9]/) {
    printf "%s", substr($1, length(prefix) + 1)
  }
}'
