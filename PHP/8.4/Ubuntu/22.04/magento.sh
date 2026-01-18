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

install-package php8.4-bcmath
install-package php8.4-curl
install-package php8.4-gd
install-package php8.4-intl
install-package php8.4-mbstring
install-package php8.4-mysql
install-package php8.4-soap
install-package php8.4-xmlrpc
install-package php8.4-xsl
install-package php8.4-zip

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
