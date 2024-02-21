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
  --help        Show this message
  --remoteHost  Remote host
  --remotePort  Remote port, default: 9000

Example: ${scriptFileName} --remoteHost 10.0.2.2
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

if [[ -z "${applicationScriptPath}" ]]; then
  >&2 echo "No application script path exported!"
  echo ""
  usage
  exit 1
fi

remoteHost=
remotePort=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${remoteHost}" ]]; then
  echo "No remote host specified!"
  exit 1
fi

if [[ -z "${remotePort}" ]]; then
  remotePort="9000"
fi

install-package build-essential

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)

if [[ "${phpVersion}" == "7.1" ]]; then
  install-package php7.1-dev
  install-package php-xml
  install-package php7.1-xml
  phpConfigurationFile="/etc/php/7.1/mods-available/xdebug.ini"
else
  >&2 echo "Unsupported PHP version: ${phpVersion}"
  exit 1
fi

install-pecl-package xdebug 2.9.8

mkdir -p /var/xdebug
chmod 0777 /var/xdebug

moduleFile=$(find /usr/lib/php/ -name xdebug.so)

echo ";zend_extension=${moduleFile}" > "${phpConfigurationFile}"

phpenmod xdebug

if [[ ! -f /.dockerenv ]]; then
  if [[ -n $(get-installed-package-version apache2) ]]; then
    service apache2 restart
  fi
  if [[ -n $(get-installed-package-version nginx) ]]; then
    service nginx restart
  fi
fi

cat <<EOF | tee /usr/local/bin/xdebug-activate > /dev/null
#!/bin/bash
cat <<EOFXA | sudo tee ${phpConfigurationFile} > /dev/null
zend_extension=${moduleFile}
xdebug.max_nesting_level=512
xdebug.remote_enable=1
xdebug.remote_autostart=1
xdebug.remote_connect_back=0
xdebug.remote_host=${remoteHost}
xdebug.remote_port=${remotePort}
EOFXA
if [[ -n \$(get-installed-package-version apache2) ]]; then
  echo "Reloading Apache"
  service apache2 reload
fi
if [[ -n \$(get-installed-package-version php${phpVersion}-fpm) ]]; then
  echo "Reloading FPM"
  kill -USR2 \$(ps aux | grep "php-fpm: master" | grep -v "grep php-fpm: master" | awk '{print $2}')
fi
export PHP_IDE_CONFIG="serverName=cli"
EOF

chmod +x /usr/local/bin/xdebug-activate

if [[ ! -f /usr/local/bin/xa ]]; then
  ln -s /usr/local/bin/xdebug-activate /usr/local/bin/xa | cat
fi

cat <<EOF | tee /usr/local/bin/xdebug-deactivate > /dev/null
#!/bin/bash
cat <<EOFXD | sudo tee ${phpConfigurationFile} > /dev/null
;zend_extension=${moduleFile}
EOFXD
if [[ -n \$(get-installed-package-version apache2) ]]; then
  echo "Reloading Apache"
  service apache2 reload
fi
if [[ -n \$(get-installed-package-version php${phpVersion}-fpm) ]]; then
  echo "Reloading FPM"
  kill -USR2 \$(ps aux | grep "php-fpm: master" | grep -v "grep php-fpm: master" | awk '{print $2}')
fi
EOF

chmod +x /usr/local/bin/xdebug-deactivate

if [[ ! -f /usr/local/bin/xd ]]; then
  ln -s /usr/local/bin/xdebug-deactivate /usr/local/bin/xd | cat
fi
