#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the PHP extensions Laravel applications use, and the PHP CLI if it is missing.

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

source "${cosysesPath}/prepare-parameters.sh"

phpVersion="${applicationVersion}"
phpPackage="php${phpVersion//./}"

if [[ -z "$(command -v "${phpPackage}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

# The same extensions as the Ubuntu routine (mysql and xml are split into several packages on Alpine)
phpExtensions=( bcmath curl gd intl mbstring mysqli pdo_mysql sqlite3 pdo_sqlite dom simplexml xml xmlreader xmlwriter zip pecl-redis )
for phpExtension in "${phpExtensions[@]}"; do
  install-package "${phpPackage}-${phpExtension}"
done

if [[ ! -f /.dockerenv ]] && [[ -x "$(command -v rc-service)" ]] && rc-service --exists "php-fpm${phpVersion//./}"; then
  rc-service "php-fpm${phpVersion//./}" restart
fi
