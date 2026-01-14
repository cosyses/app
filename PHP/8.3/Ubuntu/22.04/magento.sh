#!/bin/bash -e

echo "Checking curl"
test ! -e /usr/local/include/curl && ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl || echo "Successful"

install-package build-essential
install-package php8.3-dev
install-package php-pear 1:1.10
install-package libmcrypt-dev
install-package libxml2-dev
install-package libcurl4-openssl-dev
install-package libpcre3-dev
install-package zlib1g-dev
install-package liblzma-dev
install-package pkg-config
install-package autogen
install-package wget

install-package php8.3-bcmath
install-package php8.3-curl
install-package php8.3-gd
install-package php8.3-intl
install-package php8.3-mbstring
install-package php8.3-mysql
install-package php8.3-soap
install-package php8.3-xmlrpc
install-package php8.3-xsl
install-package php8.3-zip

install-pecl-package "mcrypt" 1.0.6

echo "Creating configuration at: /etc/php/8.3/mods-available/mcrypt.ini"
echo "extension=mcrypt.so" > /etc/php/8.3/mods-available/mcrypt.ini

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module mcrypt"
  phpenmod mcrypt
fi

echo "no" | install-pecl-package "redis" 6.2.0

echo "Creating configuration at: /etc/php/8.3/mods-available/redis.ini"
echo "extension=redis.so" > /etc/php/8.3/mods-available/redis.ini

if [[ -n $(which phpenmod) ]]; then
  echo "Enabling module redis"
  phpenmod redis
fi

if [[ -n "$(php -m | grep -e ^solr\$ | cat)" ]]; then
  echo "PHP module solr already installed"
  exit 0
fi

cd /tmp
wget -nv https://pecl.php.net/get/solr-2.8.1.tgz
tar zxvf solr-2.8.1.tgz
cd solr-2.8.1
phpize
autoconf
./configure
make
make install

echo "Creating configuration at: /etc/php/8.3/mods-available/solr.ini"
echo "extension=solr.so" > /etc/php/8.3/mods-available/solr.ini

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
