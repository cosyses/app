#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Updates an installed Shopware 6 shop after its code changed (deployment, composer update): refreshes and updates the
plugins and themes, registers the scheduled tasks, installs the assets, builds the search index if OpenSearch is
enabled, compiles the themes and clears the caches.

usage: ${scriptFileName} options

OPTIONS:
  --help         Show this message
  --appPath      Directory of the project
  --user         System user who owns the project and runs the commands, default: www-data
  --searchIndex  Build the search index (yes, no or auto: if SHOPWARE_ES_ENABLED=1), default: auto

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
searchIndex=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${searchIndex}" ]]; then
  searchIndex="auto"
fi

if [[ ! -f "${appPath}/bin/console" ]]; then
  >&2 echo "No Shopware project found in: ${appPath}"
  exit 1
fi

# Runs the Shopware console as the project user
console()
{
  echo "Running: bin/console $*"
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" php bin/console --no-interaction "$@"
  else
    php bin/console --no-interaction "$@"
  fi
}

cd "${appPath}"

if [[ "${searchIndex}" == "auto" ]]; then
  # The last definition wins, .env.local overrides .env
  searchEnabled=$(cat .env .env.local 2>/dev/null | grep -E "^SHOPWARE_ES_ENABLED=" | tail -n 1 | cut -d= -f2 | tr -d "\"'")
  if [[ "${searchEnabled}" == "1" ]]; then
    searchIndex="yes"
  else
    searchIndex="no"
  fi
fi

console plugin:refresh
console theme:refresh
console scheduled-task:register
console cache:clear:all

console plugin:update:all
console cache:clear:all

console assets:install
console cache:clear:all

if [[ "${searchIndex}" == "yes" ]]; then
  console es:index --no-queue
  console cache:clear:all
fi

console theme:compile --active-only
console cache:clear:all
