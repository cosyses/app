#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help  Show this message

Example: ${scriptFileName}
EOF
}

install-package python3-software-properties
add-ppa-repository ppa:ondrej/php
install-package php8.1
update-alternatives --set php /usr/bin/php8.1
update-alternatives --set phar /usr/bin/phar8.1
update-alternatives --set phar.phar /usr/bin/phar.phar8.1
purge-package apache2
clean-packages
install-package php-pear 1:1.10

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

replace-file-content /etc/php/8.1/cli/php.ini "max_execution_time = 14400" "max_execution_time = 30"
replace-file-content /etc/php/8.1/cli/php.ini "max_input_time = 14400" "max_input_time = 60"
replace-file-content /etc/php/8.1/cli/php.ini "memory_limit = 4096M" "memory_limit = -1"
add-file-content-after /etc/php/8.1/cli/php.ini "error_log = /var/log/php/cli.log" "error_log = syslog" 1

update-alternatives --set php "$(which php8.1)"

if [[ ! -f /.dockerenv ]]; then
  if [[ $(which apache2 | wc -l) -gt 0 ]]; then
    service apache2 restart
  fi

  if [[ $(which nginx | wc -l) -gt 0 ]]; then
    service nginx restart
  fi
fi

mkdir -p /opt/install/
crudini --set /opt/install/env.properties php version "8.1"
crudini --set /opt/install/env.properties php type "cli"
