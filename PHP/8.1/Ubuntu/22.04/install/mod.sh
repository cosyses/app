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

source "${cosysesPath}/prepare-parameters.sh"

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
if [[ -z "${phpVersion}" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli \
    --clean no
fi

install-package libapache2-mod-php8.1
install-package libcurl4-openssl-dev

replace-file-content /etc/php/8.1/apache2/php.ini "max_execution_time = 3600" "max_execution_time = 30"
replace-file-content /etc/php/8.1/apache2/php.ini "max_input_time = 3600" "max_input_time = 60"
replace-file-content /etc/php/8.1/apache2/php.ini "max_input_vars = 100000" "; max_input_vars = 1000"
replace-file-content /etc/php/8.1/apache2/php.ini "memory_limit = 4096M" "memory_limit = 128M"
add-file-content-after /etc/php/8.1/apache2/php.ini "error_log = /var/log/php/apache.log" "error_log = syslog" 1

update-alternatives --set php "$(which php8.1)"

chown www-data: /var/www

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/php.sh"
  cat <<EOF > /usr/local/bin/php.sh
#!/bin/bash -e
/usr/sbin/apache2ctl -D FOREGROUND
EOF
  chmod +x /usr/local/bin/php.sh
else
  echo "Restarting service"
  service apache2 restart
fi
