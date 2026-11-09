#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs a command line tool that is distributed as Composer package (for example rector/rector) into its own
directory below /usr/local/lib/composer-tools and links its binaries to /usr/local/bin. PHP and Composer have to be
installed (cosyses PHP <version>, cosyses Composer <version>). An existing installation of the tool is replaced.

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --packageName     Name of the Composer package, for example: rector/rector
  --packageVersion  Version constraint, for example: ~2.8.0
  --binaryNames     Comma separated names of the binaries in vendor/bin to link, default: name of the package
                    without vendor
  --toolName        Name of the directory below /usr/local/lib/composer-tools, default: name of the package without
                    vendor
  --phpExtensions   Comma separated PHP extensions the tool needs, installed as packages of the PHP version, for
                    example: mbstring,xml

Example: ${scriptFileName} --packageName rector/rector --packageVersion ~2.8.0
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

packageName=
packageVersion=
binaryNames=
toolName=
phpExtensions=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${packageName}" ]]; then
  >&2 echo "No package name specified!"
  usage
  exit 1
fi

if [[ -z "${packageVersion}" ]]; then
  >&2 echo "No package version specified!"
  usage
  exit 1
fi

if [[ -z "${binaryNames}" ]]; then
  binaryNames="${packageName##*/}"
fi

if [[ -z "${toolName}" ]]; then
  toolName="${packageName##*/}"
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP <version>)"
  exit 1
fi

if [[ ! -x "$(command -v composer)" ]]; then
  >&2 echo "Composer not found, install it first (cosyses Composer <version>)"
  exit 1
fi

if [[ -n "${phpExtensions}" ]]; then
  phpVersion=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
  IFS=',' read -r -a phpExtensionList <<< "${phpExtensions}"
  for phpExtension in "${phpExtensionList[@]}"; do
    if php -m | grep -qix "${phpExtension}"; then
      echo "PHP extension already installed: ${phpExtension}"
    elif [[ -x "$(command -v apk)" ]]; then
      # Alpine names the PHP packages without the dot, e.g. php84-mbstring
      install-package "php${phpVersion//./}-${phpExtension}"
    else
      install-package "php${phpVersion}-${phpExtension}"
    fi
  done
fi

toolPath="/usr/local/lib/composer-tools/${toolName}"

if [[ -d "${toolPath}" ]]; then
  echo "Removing previous installation in: ${toolPath}"
  rm -rf "${toolPath}"
fi

mkdir -p "${toolPath}"

echo "Installing ${packageName} ${packageVersion} into: ${toolPath}"
# the tools are installed system-wide by root
export COMPOSER_ALLOW_SUPERUSER=1
echo "{}" > "${toolPath}/composer.json"
composer require --working-dir "${toolPath}" --no-interaction --no-progress --no-cache --prefer-dist \
  "${packageName}:${packageVersion}"

IFS=',' read -r -a binaryNameList <<< "${binaryNames}"
for binaryName in "${binaryNameList[@]}"; do
  if [[ ! -f "${toolPath}/vendor/bin/${binaryName}" ]]; then
    >&2 echo "Binary not found: ${toolPath}/vendor/bin/${binaryName}"
    exit 1
  fi
  echo "Linking /usr/local/bin/${binaryName} to: ${toolPath}/vendor/bin/${binaryName}"
  ln -sfn "${toolPath}/vendor/bin/${binaryName}" "/usr/local/bin/${binaryName}"
done
