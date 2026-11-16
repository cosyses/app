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

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP <version>)"
  exit 1
fi

phpVersion=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')

if [[ ! " ${xdebugPhpVersions} " =~ \ ${phpVersion}\  ]]; then
  >&2 echo "Unsupported PHP version: ${phpVersion}"
  exit 1
fi

# Alpine names the packages with the version without the dot (php84), openSUSE with the major version (php8)
if [[ -x "$(command -v apk)" ]]; then
  phpPackage="php${phpVersion//./}"
  install-package build-base
  install-package linux-headers
  install-package "${phpPackage}-dev"
  install-package "${phpPackage}-pear"
  # The PECL command has the version in its name on Alpine
  if [[ ! -x "$(command -v pecl)" ]]; then
    ln -sfn "/usr/bin/pecl${phpVersion//./}" /usr/local/bin/pecl
  fi
  if [[ ! -x "$(command -v phpize)" ]]; then
    ln -sfn "/usr/bin/phpize${phpVersion//./}" /usr/local/bin/phpize
  fi
  if [[ ! -x "$(command -v php-config)" ]]; then
    ln -sfn "/usr/bin/php-config${phpVersion//./}" /usr/local/bin/php-config
  fi
else
  phpPackage="php${phpVersion%%.*}"
  install-package gcc
  install-package make
  install-package "${phpPackage}-devel" "${phpVersion}."
  install-package "${phpPackage}-pecl"
fi

install-pecl-package xdebug "${xdebugVersion}"

mkdir -p /var/xdebug
chmod 0777 /var/xdebug

# The CLI and FPM share the directory of additional configuration files
phpConfigurationFile="$(php -r 'echo PHP_CONFIG_FILE_SCAN_DIR;')/xdebug.ini"
moduleFile="$(php -r 'echo ini_get("extension_dir");')/xdebug.so"

if [[ ! -f "${moduleFile}" ]]; then
  >&2 echo "Could not find Xdebug module at: ${moduleFile}"
  exit 1
fi

echo "Creating configuration at: ${phpConfigurationFile}"
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
if pgrep -f "php-fpm: master" > /dev/null; then
  echo "Reloading FPM"
  sudo pkill -USR2 -f "php-fpm: master"
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
if pgrep -f "php-fpm: master" > /dev/null; then
  echo "Reloading FPM"
  sudo pkill -USR2 -f "php-fpm: master"
fi
EOF

chmod +x /usr/local/bin/xdebug-deactivate

if [[ ! -f /usr/local/bin/xd ]]; then
  ln -s /usr/local/bin/xdebug-deactivate /usr/local/bin/xd | cat
fi
