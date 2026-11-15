#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Builds an installed Magento 2 shop: upgrades the database (setup:upgrade), compiles the dependency injection
(setup:di:compile), deploys the static content for the given languages and reindexes.

usage: ${scriptFileName} options

OPTIONS:
  --help       Show this message
  --appPath    Path of the Magento installation, default: /var/www/magento/htdocs
  --user       System user who owns the installation and runs bin/magento, default: www-data
  --languages  Comma separated languages of the static content, default: en_US
  --jobs       Number of parallel jobs of the static content deployment, default: 1

Example: ${scriptFileName} --appPath /var/www/magento/htdocs --languages de_DE,en_US
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
languages=
jobs=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${languages}" ]]; then
  languages="en_US"
fi

if [[ -z "${jobs}" ]]; then
  jobs="1"
fi

if [[ ! -f "${appPath}/app/etc/env.php" ]]; then
  >&2 echo "No Magento installation found in: ${appPath}"
  exit 1
fi

runMagento()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" php "${appPath}/bin/magento" "$@" 2>&1
  else
    php "${appPath}/bin/magento" "$@" 2>&1
  fi
}

IFS=',' read -r -a languageList <<< "${languages}"

cd "${appPath}"

echo "Upgrading database"
runMagento setup:upgrade
runMagento cache:clean

echo "Compiling dependency injection"
runMagento setup:di:compile

echo "Deploying static content for languages: ${languageList[*]}"
runMagento setup:static-content:deploy --force "--jobs=${jobs}" "${languageList[@]}"
runMagento cache:clean

echo "Reindexing"
runMagento index:reindex
runMagento cache:clean
