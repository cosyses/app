#!/bin/bash -e

if [[ -n "$(php -m | grep -e ^solr\$ | cat)" ]]; then
  echo "PHP module solr already installed"
  exit 0
fi

install-package build-essential
install-package php8.4-dev
install-package php-pear 1:1.10

install-package wget
install-package tar
install-package libcurl4-openssl-dev
install-package libxml2-dev

cd /tmp
wget -nv https://pecl.php.net/get/solr-2.8.1.tgz
tar zxvf solr-2.8.1.tgz
cd solr-2.8.1
phpize
autoconf
./configure
make
make install

echo "Creating configuration at: /etc/php/8.4/mods-available/solr.ini"
echo "extension=solr.so" > /etc/php/8.4/mods-available/solr.ini

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module solr"
  phpenmod solr
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
