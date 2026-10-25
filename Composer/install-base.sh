#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${composerVersion}" ]]; then
  >&2 echo "No Composer version specified!"
  echo ""
  exit 1
fi

install-package curl

if [[ "${composerPhpCurl}" == 1 ]]; then
  phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
  install-package "php${phpVersion}-curl"
fi

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version "${composerVersion}"
