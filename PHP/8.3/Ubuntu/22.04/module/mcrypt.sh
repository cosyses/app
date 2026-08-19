#!/bin/bash -e

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

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
if [[ -z "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
elif [[ -n "$(php -m | grep -e ^mcrypt\$ | cat)" ]]; then
  echo "PHP module mcrypt already installed"
  exit 0
fi

install-package build-essential
install-package "php${phpVersion}-dev"
install-package php-pear 1:1.10

install-package libmcrypt-dev
install-pecl-package "mcrypt" 1.0.6

echo "Creating configuration at: /etc/php/${phpVersion}/mods-available/mcrypt.ini"
echo "extension=mcrypt.so" > "/etc/php/${phpVersion}/mods-available/mcrypt.ini"

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module mcrypt"
  phpenmod mcrypt
fi

if [[ ! -f /.dockerenv ]]; then
  if [[ $(get-installed-package-version apache2 | wc -l) -gt 0 ]]; then
    service apache2 restart
    sleep 5
  fi

  if [[ $(get-installed-package-version nginx | wc -l) -gt 0 ]]; then
    service nginx restart
  fi
fi
