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

if [[ "$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)" != "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

# The same extensions as the Ubuntu routine: curl is part of php-common, sqlite3 of php-pdo, phpredis is php-pecl-redis6
phpPackages=( php-bcmath php-gd php-mbstring php-intl php-mysqlnd php-pdo php-xml php-pecl-zip php-pecl-redis6 )
for phpPackage in "${phpPackages[@]}"; do
  install-package "${phpPackage}"
done

if [[ ! -f /.dockerenv ]] && [[ -n "$(get-installed-package-version php-fpm)" ]]; then
  echo "Restarting PHP FPM"
  systemctl restart php-fpm
fi
