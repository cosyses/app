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

if [[ -n "$("php${phpVersion}" -m | grep -e ^solr\$ | cat)" ]]; then
  echo "PHP module solr already installed"
  exit 0
fi

install-package build-essential
install-package "php${phpVersion}-dev"
install-package php-pear 1:1.10

install-package tar
install-package wget

if [[ "${phpVersion%%.*}" -lt 8 ]]; then
  solrVersion="2.6.0"
else
  solrVersion="2.8.1"
fi

cd /tmp
wget -nv "https://pecl.php.net/get/solr-${solrVersion}.tgz"
tar zxvf "solr-${solrVersion}.tgz"
cd "solr-${solrVersion}"

install-package libcurl4-openssl-dev
install-package libxml2-dev

phpize
autoconf
./configure
make
make install

echo "Creating configuration at: /etc/php/${phpVersion}/mods-available/solr.ini"
echo "extension=solr.so" > "/etc/php/${phpVersion}/mods-available/solr.ini"

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
