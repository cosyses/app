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

if [[ -z "$(command -v "php${phpVersion}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli \
    --clean no
fi

# Ubuntu has transitional packages with this name for Ubuntu PHP, use the version of the installed PHP
install-package "libapache2-mod-php${phpVersion}" "$(get-installed-package-version "php${phpVersion}-common")"
install-package libcurl4-openssl-dev

replace-file-content /etc/php/${phpVersion}/apache2/php.ini "max_execution_time = 3600" "max_execution_time = 30"
replace-file-content /etc/php/${phpVersion}/apache2/php.ini "max_input_time = 3600" "max_input_time = 60"
replace-file-content /etc/php/${phpVersion}/apache2/php.ini "max_input_vars = 100000" "; max_input_vars = 1000"
replace-file-content /etc/php/${phpVersion}/apache2/php.ini "memory_limit = 4096M" "memory_limit = 128M"
add-file-content-after /etc/php/${phpVersion}/apache2/php.ini "error_log = /var/log/php/apache.log" "error_log = syslog" 1

update-alternatives --set php "$(which php${phpVersion})"

chown www-data: /var/www

if [[ -f /.dockerenv ]]; then
  if [[ -f /usr/local/bin/apache.sh ]]; then
    echo "Copy start script at: /usr/local/bin/php.sh from /usr/local/bin/apache.sh"
    cp /usr/local/bin/apache.sh /usr/local/bin/php.sh
  else
    echo "Creating start script at: /usr/local/bin/php.sh"
    cat <<EOF > /usr/local/bin/php.sh
#!/bin/bash -e
/usr/sbin/apache2ctl -D FOREGROUND
EOF
  fi
  chmod +x /usr/local/bin/php.sh
else
  echo "Restarting service"
  service apache2 restart
fi
