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

source "${cosysesPath}/prepare-parameters.sh"

# The module stream replaces the PHP of the distribution, so PHP has the usual paths: /usr/bin/php, /etc/php.ini,
# /etc/php.d, /usr/sbin/php-fpm
add-remi-repository
enable-dnf-module php "remi-${phpVersion}"

install-package php-cli "${phpVersion}"

# The extensions Ubuntu's PHP CLI contains (the others are part of php-common and php-cli)
phpPackages=( php-common php-opcache php-pdo php-process php-sodium php-xml php-pear )
for phpPackage in "${phpPackages[@]}"; do
  install-package "${phpPackage}"
done

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

# RHEL has one php.ini for the CLI and FPM, FPM gets its limits from the pool configuration
replace-file-content /etc/php.ini "max_execution_time = 14400" "max_execution_time = 30"
replace-file-content /etc/php.ini "max_input_time = 14400" "max_input_time = 60"
replace-file-content /etc/php.ini "memory_limit = 4096M" "memory_limit = 128M"

mkdir -p /var/www
chown www-data: /var/www

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
