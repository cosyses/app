#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help  Show this message

Example: ${scriptName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

version="2.12.0"

cd /tmp

curl -L -O "https://github.com/wp-cli/wp-cli/releases/download/v${version}/wp-cli-${version}.phar"

mv "wp-cli-${version}.phar" /usr/local/bin/wp
chmod +x /usr/local/bin/wp
