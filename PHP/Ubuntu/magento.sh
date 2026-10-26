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

echo "Checking curl"
test ! -e /usr/local/include/curl && ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl || echo "Successful"

install-package libpcre3-dev
install-package zlib1g-dev
install-package liblzma-dev
install-package pkg-config
install-package autogen

phpVersion="${applicationVersion}"
if [[ -z "$(command -v "php${phpVersion}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

install-package "php${phpVersion}-bcmath"
install-package "php${phpVersion}-curl"
install-package "php${phpVersion}-gd"
install-package "php${phpVersion}-intl"
install-package "php${phpVersion}-mbstring"
install-package "php${phpVersion}-mysql"
install-package "php${phpVersion}-soap"
install-package "php${phpVersion}-xmlrpc"
install-package "php${phpVersion}-xsl"
install-package "php${phpVersion}-zip"

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript module/mcrypt.sh

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript module/redis.sh

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript module/solr.sh

if [[ ! -f /.dockerenv ]]; then
  if [[ $(get-installed-package-version apache2 | wc -l) -gt 0 ]]; then
    service apache2 restart
    sleep 5
  fi

  if [[ $(get-installed-package-version nginx | wc -l) -gt 0 ]]; then
    service nginx restart
  fi
fi
