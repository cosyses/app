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
  --help   Show this message
  --clean  Flag if apache packages should be cleaned, default: yes

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

clean=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${clean}" ]]; then
  clean="yes"
fi

install-package python3-software-properties
add-ppa-repository ppa:ondrej/php
install-package php5.6
update-alternatives --set php /usr/bin/php5.6
update-alternatives --set phar /usr/bin/phar5.6
update-alternatives --set phar.phar /usr/bin/phar.phar5.6
if [[ "${clean}" == "yes" ]]; then
  echo "Cleaning Apache packages"
  purge-package apache2
  clean-packages
fi
install-package php-pear 1:1.10

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

replace-file-content /etc/php/5.6/cli/php.ini "max_execution_time = 14400" "max_execution_time = 30"
replace-file-content /etc/php/5.6/cli/php.ini "max_input_time = 14400" "max_input_time = 60"
replace-file-content /etc/php/5.6/cli/php.ini "memory_limit = 4096M" "memory_limit = -1"
add-file-content-after /etc/php/5.6/cli/php.ini "error_log = /var/log/php/cli.log" "error_log = syslog" 1

update-alternatives --set php "$(which php5.6)"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/php.sh"
  cat <<EOF > /usr/local/bin/php.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping PHP CLI"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting PHP CLI"
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/php.sh
fi
