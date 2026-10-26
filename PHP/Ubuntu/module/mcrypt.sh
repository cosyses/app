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

phpVersion="${applicationVersion}"
if [[ -z "$(command -v "php${phpVersion}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

if [[ -n "$("php${phpVersion}" -m | grep -e ^mcrypt\$ | cat)" ]]; then
  echo "PHP module mcrypt already installed"
  exit 0
fi

install-package build-essential
install-package "php${phpVersion}-dev"
install-package php-pear 1:1.10

# For PHP 5 mcrypt is a regular extension package
if [[ "${phpVersion%%.*}" -lt 7 ]]; then
  install-package "php${phpVersion}-mcrypt"
else
  install-package libmcrypt-dev
  install-pecl-package "mcrypt" 1.0.9

  echo "Creating configuration at: /etc/php/${phpVersion}/mods-available/mcrypt.ini"
  echo "extension=mcrypt.so" > "/etc/php/${phpVersion}/mods-available/mcrypt.ini"
fi

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
