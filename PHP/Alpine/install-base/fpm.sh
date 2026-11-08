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

phpPackage="php${phpVersion//./}"

if [[ -z "$(command -v "${phpPackage}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

install-package "${phpPackage}-fpm"

fpmConfigPath="/etc/${phpPackage}"
fpmBinary="/usr/sbin/php-fpm${phpVersion//./}"
pidFile="/run/php-fpm${phpVersion//./}.pid"

echo "Configuring pool at: ${fpmConfigPath}/php-fpm.d/www.conf"
sed -i -e "s/^user = .*/user = www-data/" -e "s/^group = .*/group = www-data/" -e "s/^listen = .*/listen = ${bindAddress}:${port}/" "${fpmConfigPath}/php-fpm.d/www.conf"
sed -i -e "s#^;*pid = .*#pid = ${pidFile}#" -e "s#^;*error_log = .*#error_log = /var/log/php/fpm.log#" "${fpmConfigPath}/php-fpm.conf"

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
${fpmBinary} --fpm-config ${fpmConfigPath}/php-fpm.conf
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/php.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-php.sh"
    cat <<EOF > /usr/local/lib/start/10-php.sh
#!/usr/bin/env bash
echo "Starting PHP FPM"
${fpmBinary} --fpm-config ${fpmConfigPath}/php-fpm.conf
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
elif [[ -x "$(command -v rc-service)" ]]; then
  echo "Starting service"
  rc-update add "php-fpm${phpVersion//./}" default
  rc-service "php-fpm${phpVersion//./}" restart
fi
