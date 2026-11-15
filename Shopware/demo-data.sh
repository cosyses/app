#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Adds the demo data of Shopware (plugin SwagPlatformDemoData, cloned with git into custom/plugins) to an installed
Shopware 6 shop and installs and activates the plugin, which creates the demo products, categories and customers.

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --appPath         Directory of the project
  --user            System user who owns the project and runs the commands, default: www-data
  --repositoryUrl   Git repository of the plugin, default: https://github.com/shopware/SwagPlatformDemoData.git
  --branch          Branch or tag of the plugin, default: the default branch of the repository

Example: ${scriptFileName} --appPath /var/www/shop
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
repositoryUrl=
branch=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${repositoryUrl}" ]]; then
  repositoryUrl="https://github.com/shopware/SwagPlatformDemoData.git"
fi

if [[ ! -f "${appPath}/bin/console" ]]; then
  >&2 echo "No Shopware project found in: ${appPath}"
  exit 1
fi

# Runs a command as the project user
runAsUser()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" "$@"
  else
    "$@"
  fi
}

if [[ ! -x "$(command -v git)" ]]; then
  if [[ "$(id -u)" != 0 ]]; then
    >&2 echo "Git not found and cannot be installed as user: $(whoami), install it first as root (install-package git)"
    exit 1
  fi
  install-package git
fi

cd "${appPath}"

pluginPath="custom/plugins/SwagPlatformDemoData"
if [[ -d "${pluginPath}" ]]; then
  echo "Demo data plugin already exists in: ${appPath}/${pluginPath}"
else
  cloneArguments=( clone --depth 1 )
  if [[ -n "${branch}" ]]; then
    cloneArguments+=( --branch "${branch}" )
  fi
  echo "Cloning demo data plugin from: ${repositoryUrl}"
  runAsUser mkdir -p custom/plugins
  runAsUser git "${cloneArguments[@]}" "${repositoryUrl}" "${pluginPath}"
fi

runAsUser php bin/console plugin:refresh --no-interaction
runAsUser php bin/console plugin:install --activate --no-interaction SwagPlatformDemoData
runAsUser php bin/console cache:clear:all --no-interaction
