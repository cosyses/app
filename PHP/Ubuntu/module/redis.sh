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

if [[ -n "$("php${phpVersion}" -m | grep -e ^redis\$ | cat)" ]]; then
  echo "PHP module redis already installed"
  exit 0
fi

install-package build-essential
install-package "php${phpVersion}-dev"
install-package php-pear 1:1.10

if [[ "${phpVersion%%.*}" -lt 7 ]]; then
  echo "no" | install-pecl-package "redis" 4.3.0
elif [[ "${phpVersion%%.*}" -lt 8 ]]; then
  echo "no" | install-pecl-package "redis" 5.3.7
else
  echo "no" | install-pecl-package "redis" 6.2.0
fi

echo "Creating configuration at: /etc/php/${phpVersion}/mods-available/redis.ini"
echo "extension=redis.so" > "/etc/php/${phpVersion}/mods-available/redis.ini"

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
