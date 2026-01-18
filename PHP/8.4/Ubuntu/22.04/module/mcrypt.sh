#!/bin/bash -e

if [[ -n "$(php -m | grep -e ^mcrypt\$ | cat)" ]]; then
  echo "PHP module mcrypt already installed"
  exit 0
fi

install-package build-essential
install-package php8.4-dev
install-package php-pear 1:1.10

install-package libmcrypt-dev

install-pecl-package "mcrypt" 1.0.9

echo "Creating configuration at: /etc/php/8.4/mods-available/mcrypt.ini"
echo "extension=mcrypt.so" > /etc/php/8.4/mods-available/mcrypt.ini

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
