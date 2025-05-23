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
  --remotePort  Remote port, default: 9003

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
  remotePort="9003"
fi

install-package build-essential

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)

if [[ "${phpVersion}" == "8.0" ]]; then
  install-package php8.0-dev
  install-package php-xml
  install-package php8.0-xml
  phpConfigurationFile="/etc/php/8.0/mods-available/xdebug.ini"
elif [[ "${phpVersion}" == "8.1" ]]; then
  install-package php8.1-dev
  install-package php-xml
  install-package php8.1-xml
  phpConfigurationFile="/etc/php/8.1/mods-available/xdebug.ini"
elif [[ "${phpVersion}" == "8.2" ]]; then
  install-package php8.2-dev
  install-package php-xml
  install-package php8.2-xml
  phpConfigurationFile="/etc/php/8.2/mods-available/xdebug.ini"
elif [[ "${phpVersion}" == "8.3" ]]; then
  install-package php8.3-dev
  install-package php-xml
  install-package php8.3-xml
  phpConfigurationFile="/etc/php/8.3/mods-available/xdebug.ini"
else
  >&2 echo "Unsupported PHP version: ${phpVersion}"
  exit 1
fi

install-pecl-package xdebug 3.3.2

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
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.discover_client_host=0
xdebug.client_host=${remoteHost}
xdebug.client_port=${remotePort}
EOFXA
if [[ -n \$(get-installed-package-version apache2) ]]; then
  echo "Reloading Apache"
  service apache2 reload
fi
if [[ -n \$(get-installed-package-version php${phpVersion}-fpm) ]]; then
  echo "Reloading FPM"
  kill -USR2 \$(ps aux | grep "php-fpm: master" | grep -v "grep php-fpm: master" | awk '{print \$2}')
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
  kill -USR2 \$(ps aux | grep "php-fpm: master" | grep -v "grep php-fpm: master" | awk '{print \$2}')
fi
EOF

chmod +x /usr/local/bin/xdebug-deactivate

if [[ ! -f /usr/local/bin/xd ]]; then
  ln -s /usr/local/bin/xdebug-deactivate /usr/local/bin/xd | cat
fi
