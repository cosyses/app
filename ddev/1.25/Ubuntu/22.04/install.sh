#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help  Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

add-gpg-repository "ddev.list" "https://pkg.ddev.com/apt/" "*" "*" "https://pkg.ddev.com/apt/gpg.key" "n"

install-package ddev 1.25

if [[ $(cat /proc/version | tr '[:upper:]' '[:lower:]' | grep "wsl2" | wc -l) -eq 1 ]]; then
  install-package ddev-wsl2 1.25
fi
