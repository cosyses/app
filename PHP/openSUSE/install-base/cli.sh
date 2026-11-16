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

# openSUSE names the packages by the major version only (php8), the version prefix selects the minor version
phpPackage="php${phpVersion%%.*}"

# The distribution has one PHP version per release (Leap 15.6: 8.2, Leap 16.0: 8.4), other versions come from the PHP
# repositories of the openSUSE build service, which build every version for the maintained Leap releases
if [[ -z "$(get-available-package-versions "${phpPackage}" "${phpVersion}.")" ]]; then
  release=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')
  add-zypper-repository "php${phpVersion//./}" "https://download.opensuse.org/repositories/devel:/languages:/php:/php${phpVersion//./}/openSUSE_Leap_${release}/"
fi

install-package "${phpPackage}" "${phpVersion}."
install-package "${phpPackage}-cli" "${phpVersion}."

# openSUSE splits the PHP extensions into packages, these are the ones Ubuntu's PHP CLI contains
phpExtensions=( calendar ctype exif ffi fileinfo ftp gettext iconv opcache openssl pcntl pdo phar posix shmop sockets sodium sysvmsg sysvsem sysvshm tokenizer )
# The sodium package of the build service for Leap 15.6 needs a newer libsodium than the release has
if [[ "$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')" == "15.6" ]]; then
  phpExtensions=( "${phpExtensions[@]/sodium}" )
fi
for phpExtension in "${phpExtensions[@]}"; do
  if [[ -n "${phpExtension}" ]]; then
    install-package "${phpPackage}-${phpExtension}" "${phpVersion}."
  fi
done

mkdir -p /var/log/php
chown root:www-data /var/log/php
chmod 0660 /var/log/php

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
