#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs PHP extensions that are distributed as packages of the PHP version (php<version>-<extension>). Extensions
that are already loaded are skipped. The PHP CLI is installed first if it is missing.

usage: ${scriptFileName} options

OPTIONS:
  --help        Show this message
  --extensions  Comma separated names of the extensions, for example: gmp,mbstring,zip

Example: ${scriptFileName} --extensions gmp,mbstring,zip
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  exit 1
fi

extensions=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${extensions}" ]]; then
  >&2 echo "No extensions specified!"
  usage
  exit 1
fi

phpVersion="${applicationVersion}"
if [[ -z "$(command -v "php${phpVersion}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

IFS=',' read -r -a extensionList <<< "${extensions}"
for extension in "${extensionList[@]}"; do
  if "php${phpVersion}" -m | grep -qix "${extension}"; then
    echo "PHP extension already installed: ${extension}"
  else
    install-package "php${phpVersion}-${extension}"
  fi
done
