#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Builds Xdebug with PECL for the PHP of Remi's repository on RHEL and Fedora (installed with cosyses PHP). The module is
configured but inactive, xdebug-activate (xa) and xdebug-deactivate (xd) switch it on and off.

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

# Set by the version specific install.sh which sources this script
if [[ -z "${xdebugVersion}" ]]; then
  >&2 echo "No Xdebug version specified!"
  echo ""
  exit 1
fi

if [[ -z "${xdebugPhpVersions}" ]]; then
  >&2 echo "No supported PHP versions specified!"
  echo ""
  exit 1
fi

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
if [[ -z "${phpVersion}" ]]; then
  >&2 echo "No PHP installed, install it with cosyses PHP first"
  exit 1
fi
if [[ ! " ${xdebugPhpVersions} " =~ \ ${phpVersion}\  ]]; then
  >&2 echo "Unsupported PHP version: ${phpVersion}"
  exit 1
fi

# php-devel comes from the same module stream of Remi's repository as the installed PHP
install-package gcc
install-package make
install-package php-devel
install-package php-pear
install-package php-xml

install-pecl-package xdebug "${xdebugVersion}"

mkdir -p /var/xdebug
chmod 0777 /var/xdebug

moduleFile=$(find /usr/lib64/php/modules -name xdebug.so | head -1)
if [[ -z "${moduleFile}" ]]; then
  >&2 echo "Could not find the built module xdebug.so"
  exit 1
fi

phpConfigurationFile="/etc/php.d/15-xdebug.ini"
echo ";zend_extension=${moduleFile}" > "${phpConfigurationFile}"

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
if pgrep -f "php-fpm: master" >/dev/null; then
  echo "Reloading FPM"
  sudo kill -USR2 \$(pgrep -f "php-fpm: master")
fi
export PHP_IDE_CONFIG="serverName=cli"
EOF
chmod +x /usr/local/bin/xdebug-activate
if [[ ! -e /usr/local/bin/xa ]]; then
  ln -s /usr/local/bin/xdebug-activate /usr/local/bin/xa
fi

cat <<EOF | tee /usr/local/bin/xdebug-deactivate > /dev/null
#!/bin/bash
cat <<EOFXD | sudo tee ${phpConfigurationFile} > /dev/null
;zend_extension=${moduleFile}
EOFXD
if pgrep -f "php-fpm: master" >/dev/null; then
  echo "Reloading FPM"
  sudo kill -USR2 \$(pgrep -f "php-fpm: master")
fi
EOF
chmod +x /usr/local/bin/xdebug-deactivate
if [[ ! -e /usr/local/bin/xd ]]; then
  ln -s /usr/local/bin/xdebug-deactivate /usr/local/bin/xd
fi
