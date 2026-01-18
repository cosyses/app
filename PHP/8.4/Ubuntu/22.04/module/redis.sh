#!/bin/bash -e

if [[ -n "$(php -m | grep -e ^redis\$ | cat)" ]]; then
  echo "PHP module redis already installed"
  exit 0
fi

install-package build-essential
install-package php8.4-dev
install-package php-pear 1:1.10

echo "no" | install-pecl-package "redis" 6.2.0

echo "Creating configuration at: /etc/php/8.4/mods-available/redis.ini"
echo "extension=redis.so" > /etc/php/8.4/mods-available/redis.ini

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module redis"
  phpenmod redis
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
