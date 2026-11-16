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
phpPackage="php${phpVersion%%.*}"

if [[ ! -x "$(command -v php)" ]] || [[ "$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')" != "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

# The same extensions as the Ubuntu routine (mysql contains mysqli and pdo_mysql, sqlite contains sqlite3 and pdo_sqlite,
# xml is split into several packages on openSUSE)
phpExtensions=( bcmath curl gd intl mbstring mysql sqlite dom xmlreader xmlwriter zip )
for phpExtension in "${phpExtensions[@]}"; do
  install-package "${phpPackage}-${phpExtension}" "${phpVersion}."
done

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript module/redis.sh

if [[ ! -f /.dockerenv ]] && [[ -x "$(command -v systemctl)" ]] && systemctl is-active --quiet php-fpm; then
  systemctl restart php-fpm
fi
