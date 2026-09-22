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
  --size  Value to set upload size to

Example: ${scriptFileName} --size 512M
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  usage
  exit 1
fi

size=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${size}" ]]; then
  >&2 echo "So size specified!"
  usage
  exit 1
fi

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)

if [[ -f "/etc/php/${phpVersion}/cli/php.ini" ]]; then
  replace-file-content "/etc/php/${phpVersion}/cli/php.ini" "post_max_size = ${size}" "post_max_size = 8M"
  replace-file-content "/etc/php/${phpVersion}/cli/php.ini" "upload_max_filesize = ${size}" "upload_max_filesize = 2M"
fi

if [[ -f "/etc/php/${phpVersion}/apache2/php.ini" ]]; then
  replace-file-content "/etc/php/${phpVersion}/apache2/php.ini" "post_max_size = ${size}" "post_max_size = 8M"
  replace-file-content "/etc/php/${phpVersion}/apache2/php.ini" "upload_max_filesize = ${size}" "upload_max_filesize = 2M"
fi

if [[ -f "/etc/php/${phpVersion}/fpm/php.ini" ]]; then
  replace-file-content "/etc/php/${phpVersion}/fpm/php.ini" "post_max_size = ${size}" "post_max_size = 8M"
  replace-file-content "/etc/php/${phpVersion}/fpm/php.ini" "upload_max_filesize = ${size}" "upload_max_filesize = 2M"
fi

if [[ -f /.dockerenv ]]; then
  echo "Reloading FPM"
  kill -USR2 "$(ps aux | grep "php-fpm: master" | grep -v "grep php-fpm: master" | awk '{print $2}')"
else
  systemctl restart "php${phpVersion}-fpm"
fi
