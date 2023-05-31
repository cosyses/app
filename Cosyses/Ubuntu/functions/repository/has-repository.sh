#!/bin/bash -e

urlPart="${1}"
if [[ $(find /etc/apt/ -name "*.list" | xargs cat | grep  "^[[:space:]]*deb" | grep -v deb-src | grep "${urlPart}" | wc -l) -gt 0 ]]; then
  exit 0
else
  exit 1
fi
