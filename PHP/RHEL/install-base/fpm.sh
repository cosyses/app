#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${phpVersion}" ]]; then
  >&2 echo "No PHP version set!"
  echo ""
  exit 1
fi

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
  usage
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  usage
  exit 1
fi

bindAddress=
port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]]; then
  port="9000"
fi

if [[ "$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)" != "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

install-package php-fpm "${phpVersion}"

fpmConfigFile="/etc/php-fpm.conf"
poolConfigFile="/etc/php-fpm.d/www.conf"
pidFile="/run/php-fpm/php-fpm.pid"

echo "Configuring FPM at: ${fpmConfigFile}"
sed -i -e "s#^;*pid = .*#pid = ${pidFile}#" -e "s#^;*error_log = .*#error_log = /var/log/php/fpm.log#" -e "s#^;*daemonize = .*#daemonize = yes#" "${fpmConfigFile}"

# The pool of RHEL runs as apache and only accepts local clients on a socket, Ubuntu's runs as www-data on a port
echo "Configuring pool at: ${poolConfigFile}"
sed -i \
  -e "s/^user = .*/user = www-data/" \
  -e "s/^group = .*/group = www-data/" \
  -e "s/^listen = .*/listen = ${bindAddress}:${port}/" \
  -e "s/^listen.allowed_clients = /;listen.allowed_clients = /" \
  -e "s/^listen.acl_users = /;listen.acl_users = /" \
  -e "s/^;*request_terminate_timeout = .*/request_terminate_timeout = 3600/" \
  "${poolConfigFile}"

# The limits Ubuntu's FPM has in its own php.ini
add-file-content-after "${poolConfigFile}" "php_admin_value[memory_limit] = 4096M" "php_admin_flag[log_errors] = on" 1
add-file-content-after "${poolConfigFile}" "php_value[max_execution_time] = 3600" "php_admin_value[memory_limit] = 4096M" 1
add-file-content-after "${poolConfigFile}" "php_value[max_input_time] = 3600" "php_value[max_execution_time] = 3600" 1
add-file-content-after "${poolConfigFile}" "php_value[max_input_vars] = 100000" "php_value[max_input_time] = 3600" 1

# Sessions, the WSDL cache and the file cache of OPcache belong to the group apache
for dataPath in /var/lib/php/session /var/lib/php/wsdlcache /var/lib/php/opcache; do
  if [[ -d "${dataPath}" ]]; then
    chgrp www-data "${dataPath}"
  fi
done

mkdir -p "$(dirname "${pidFile}")"
chown www-data: /var/www

echo "Testing configuration"
/usr/sbin/php-fpm --test --fpm-config "${fpmConfigFile}"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/php.sh"
  cat <<EOF > /usr/local/bin/php.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping PHP FPM"
  cat ${pidFile} | xargs kill -15 && until test ! -f ${pidFile}; do sleep 1; done
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting PHP FPM"
mkdir -p $(dirname "${pidFile}")
/usr/sbin/php-fpm --fpm-config ${fpmConfigFile}
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/php.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-php.sh"
    cat <<EOF > /usr/local/lib/start/10-php.sh
#!/usr/bin/env bash
echo "Starting PHP FPM"
mkdir -p $(dirname "${pidFile}")
/usr/sbin/php-fpm --fpm-config ${fpmConfigFile}
EOF
    chmod +x /usr/local/lib/start/10-php.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-php.sh"
    cat <<EOF > /usr/local/lib/stop/10-php.sh
#!/usr/bin/env bash
echo "Stopping PHP FPM"
cat ${pidFile} | xargs kill -15 && until test ! -f ${pidFile}; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-php.sh
  fi
else
  echo "Starting service"
  systemctl enable php-fpm --now
  systemctl restart php-fpm
fi
