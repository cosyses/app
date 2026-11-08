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

# Alpine packages are named without the dot, e.g. php84
phpPackage="php${phpVersion//./}"

install-package "${phpPackage}"

# Alpine splits the PHP extensions into packages, these are the ones Ubuntu's PHP CLI contains
phpExtensions=( calendar ctype exif ffi fileinfo ftp gettext iconv opcache openssl pcntl pdo phar posix session shmop sockets sodium sysvmsg sysvsem sysvshm tokenizer pear )
for phpExtension in "${phpExtensions[@]}"; do
  install-package "${phpPackage}-${phpExtension}"
done

echo "Linking php to: /usr/bin/${phpPackage}"
ln -sfn "/usr/bin/${phpPackage}" /usr/bin/php

# Alpine has the group www-data (82), but not the user
if ! id www-data >/dev/null 2>&1; then
  echo "Creating user: www-data"
  useradd --system --uid 82 --gid www-data --home-dir /var/www --no-create-home --shell /sbin/nologin www-data
fi

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
