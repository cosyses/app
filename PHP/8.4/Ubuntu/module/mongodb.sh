#!/bin/bash -e

if [[ -n "$(php -m | grep -e ^mongodb\$ | cat)" ]]; then
  echo "PHP module mongodb already installed"
  exit 0
fi

install-package build-essential
install-package php8.4-dev
install-package php-pear 1:1.10

echo "no" | install-pecl-package "mongodb" 2.1.4

echo "Creating configuration at: /etc/php/8.4/mods-available/mongodb.ini"
echo "extension=mongodb.so" > /etc/php/8.4/mods-available/mongodb.ini

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module mongodb"
  phpenmod mongodb
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
