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
install-package php7.4
update-alternatives --set php /usr/bin/php7.4
update-alternatives --set phar /usr/bin/phar7.4
update-alternatives --set phar.phar /usr/bin/phar.phar7.4
purge-package apache2
clean-packages
install-package php-pear 1:1.10
install-package libxml2-dev
install-package libcurl4-openssl-dev
install-package libpcre3-dev

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

replace-file-content /etc/php/7.4/cli/php.ini "max_execution_time = 14400" "max_execution_time = 30"
replace-file-content /etc/php/7.4/cli/php.ini "max_input_time = 14400" "max_input_time = 60"
replace-file-content /etc/php/7.4/cli/php.ini "memory_limit = 4096M" "memory_limit = -1"
add-file-content-after /etc/php/7.4/cli/php.ini "error_log = /var/log/php/cli.log" "error_log = syslog" 1
