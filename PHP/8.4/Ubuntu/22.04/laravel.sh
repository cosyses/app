#!/bin/bash -e

echo "Checking curl"
test ! -e /usr/local/include/curl && ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl || echo "Successful"

install-package php8.4-curl
install-package php8.4-mbstring
install-package php8.4-mysql
install-package php8.4-xml

if [[ ! -f /.dockerenv ]]; then
  if [[ $(get-installed-package-version apache2 | wc -l) -gt 0 ]]; then
    service apache2 restart
    sleep 5
  fi

  if [[ $(get-installed-package-version nginx | wc -l) -gt 0 ]]; then
    service nginx restart
  fi
fi
