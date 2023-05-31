#!/bin/bash -e

packageName="${1}"

/usr/bin/dpkg-query -W "${packageName}" 2>/dev/null | grep -P "^${packageName}" | cat | awk '{print $2}'
