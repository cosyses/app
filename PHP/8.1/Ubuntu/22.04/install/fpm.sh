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
  --help         Show this message
  --bindAddress  Host name or ip address, default: 127.0.0.1
  --port         Port of installation, default: 9000

Example: ${scriptFileName} --port 9000
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

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

bindAddress=
port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]]; then
  port="3000"
fi

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
if [[ -z "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

install-package php8.1-fpm

echo "Stopping service"
service php8.1-fpm stop

replace-file-content /etc/php/8.1/fpm/php-fpm.conf "error_log = /var/log/php/fpm.log" "error_log = /var/log/php8.1-fpm.log"

replace-file-content /etc/php/8.1/fpm/php.ini "max_execution_time = 3600" "max_execution_time = 30"
replace-file-content /etc/php/8.1/fpm/php.ini "max_input_time = 3600" "max_input_time = 60"
replace-file-content /etc/php/8.1/fpm/php.ini "max_input_vars = 100000" "; max_input_vars = 1000"
replace-file-content /etc/php/8.1/fpm/php.ini "memory_limit = 4096M" "memory_limit = 128M"
add-file-content-after /etc/php/8.1/fpm/php.ini "error_log = /var/log/php/fpm.log" "error_log = syslog" 1

replace-file-content /etc/php/8.1/fpm/pool.d/www.conf "request_terminate_timeout = 3600" ";request_terminate_timeout = 0"
replace-file-content /etc/php/8.1/fpm/pool.d/www.conf "listen = ${bindAddress}:${port}" "listen = /run/php/php8.1-fpm.sock"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/php.sh"
  cat <<EOF > /usr/local/bin/php.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping PHP FPM"
  kill "\$(cat /run/php/php8.1-fpm.pid)"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting PHP FPM"
mkdir -p /run/php
/usr/sbin/php-fpm8.1 --fpm-config /etc/php/8.1/fpm/php-fpm.conf
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/php.sh
else
  echo "Starting service"
  service php8.1-fpm start

  echo "Enabling autostart"
  systemctl enable php8.1-fpm --now
fi
