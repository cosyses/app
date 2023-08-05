#!/bin/bash -e

install-package python3-software-properties
add-ppa-repository ppa:ondrej/php
install-package libc6 2.35
install-package php7.4
update-alternatives --set php /usr/bin/php7.4
update-alternatives --set phar /usr/bin/phar7.4
update-alternatives --set phar.phar /usr/bin/phar.phar7.4
purge-package apache2
clean-packages
install-package php7.4-fpm
install-package php7.4-cli
install-package php-pear 1:1.10
install-package libxml2-dev
install-package libcurl4-openssl-dev
install-package libpcre3-dev
purge-package apache2
clean-packages

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

replace-file-content /etc/php/7.4/fpm/php-fpm.conf "error_log = /var/log/php/fpm.log" "error_log = /var/log/php7.4-fpm.log"

replace-file-content /etc/php/7.4/fpm/php.ini "max_execution_time = 3600" "max_execution_time = 30"
replace-file-content /etc/php/7.4/fpm/php.ini "max_input_time = 3600" "max_input_time = 60"
replace-file-content /etc/php/7.4/fpm/php.ini "max_input_vars = 100000" "; max_input_vars = 1000"
replace-file-content /etc/php/7.4/fpm/php.ini "memory_limit = 4096M" "memory_limit = 128M"
add-file-content-after /etc/php/7.4/fpm/php.ini "error_log = /var/log/php/fpm.log" "error_log = syslog" 1

replace-file-content /etc/php/7.4/fpm/pool.d/www.conf "request_terminate_timeout = 3600" ";request_terminate_timeout = 0"

if [[ -f /.dockerenv ]]; then
  replace-file-content /etc/php/7.4/fpm/pool.d/www.conf "listen = 127.0.0.1:3000" "listen = /run/php/php7.4-fpm.sock"
fi

replace-file-content /etc/php/7.4/cli/php.ini "max_execution_time = 14400" "max_execution_time = 30"
replace-file-content /etc/php/7.4/cli/php.ini "max_input_time = 14400" "max_input_time = 60"
replace-file-content /etc/php/7.4/cli/php.ini "memory_limit = 4096M" "memory_limit = -1"
add-file-content-after /etc/php/7.4/cli/php.ini "error_log = /var/log/php/cli.log" "error_log = syslog" 1

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/php.sh"
  cat <<EOF > /usr/local/bin/php.sh
#!/bin/bash -e
mkdir -p /run/php
/usr/sbin/php-fpm7.4 --nodaemonize --fpm-config /etc/php/7.4/fpm/php-fpm.conf
EOF
  chmod +x /usr/local/bin/php.sh
else
  echo "Restarting Service"
  service php7.4-fpm restart

  echo "Enabling autostart"
  systemctl enable php7.4-fpm --now
fi
