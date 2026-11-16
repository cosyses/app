#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the PHP extension redis (phpredis) with PECL, the same version as the Ubuntu routine, and the PHP CLI if it is
missing.

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

if php -m | grep -qx redis; then
  echo "PHP module redis already installed"
  exit 0
fi

install-package gcc
install-package make
install-package "${phpPackage}-devel" "${phpVersion}."
install-package "${phpPackage}-pecl"

if [[ "${phpVersion%%.*}" -eq 8 ]] && [[ "${phpVersion#*.}" -lt 5 ]]; then
  echo "no" | install-pecl-package "redis" 6.2.0
else
  # 6.2.0 does not compile with PHP 8.5
  echo "no" | install-pecl-package "redis" 6.3.0
fi

# The configuration directory is shared by the CLI and FPM
configurationPath=$(php -r 'echo PHP_CONFIG_FILE_SCAN_DIR;')
echo "Creating configuration at: ${configurationPath}/redis.ini"
echo "extension=redis.so" > "${configurationPath}/redis.ini"

if [[ ! -f /.dockerenv ]] && [[ -x "$(command -v systemctl)" ]] && systemctl is-active --quiet php-fpm; then
  systemctl restart php-fpm
fi
