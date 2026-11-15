#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Configures an installed Magento 2 shop to keep its cache, full page cache and sessions in Redis or Valkey. Magento
supports the backend valkey from 2.4.9; older versions use the backend redis, which works with Valkey servers too.

usage: ${scriptFileName} options

OPTIONS:
  --help                   Show this message
  --appPath                Path of the Magento installation, default: /var/www/magento/htdocs
  --user                   System user who owns the installation and runs bin/magento, default: www-data
  --cacheType              redis or valkey, default: redis
  --cacheHost              Host of the cache, default: localhost
  --cachePort              Port of the cache, default: 6379
  --cacheDatabase          Database of the cache, default: 0
  --cachePassword          Password of the cache, default: none
  --cachePrefix            Prefix of the cache ids, default: cache_
  --fullPageCacheHost      Host of the full page cache, default: the cache host
  --fullPageCachePort      Port of the full page cache, default: the cache port
  --fullPageCacheDatabase  Database of the full page cache, default: 1
  --fullPageCachePassword  Password of the full page cache, default: the cache password
  --fullPageCachePrefix    Prefix of the full page cache ids, default: fpc_
  --sessionHost            Host of the sessions, default: the cache host
  --sessionPort            Port of the sessions, default: the cache port
  --sessionDatabase        Database of the sessions, default: 2
  --sessionPassword        Password of the sessions, default: the cache password

Example: ${scriptFileName} --cacheType valkey --cacheHost cache --cachePort 6379
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
cacheType=
cacheHost=
cachePort=
cacheDatabase=
cachePassword=
cachePrefix=
fullPageCacheHost=
fullPageCachePort=
fullPageCacheDatabase=
fullPageCachePassword=
fullPageCachePrefix=
sessionHost=
sessionPort=
sessionDatabase=
sessionPassword=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${cacheType}" ]]; then
  cacheType="redis"
fi

cacheType=$(echo "${cacheType}" | tr '[:upper:]' '[:lower:]')
if [[ "${cacheType}" != "redis" ]] && [[ "${cacheType}" != "valkey" ]]; then
  >&2 echo "Invalid cache type: ${cacheType}, use redis or valkey"
  usage
  exit 1
fi

if [[ -z "${cacheHost}" ]]; then
  cacheHost="localhost"
fi

if [[ -z "${cachePort}" ]]; then
  cachePort="6379"
fi

if [[ -z "${cacheDatabase}" ]]; then
  cacheDatabase="0"
fi

if [[ -z "${cachePrefix}" ]]; then
  cachePrefix="cache_"
fi

if [[ -z "${fullPageCacheHost}" ]]; then
  fullPageCacheHost="${cacheHost}"
fi

if [[ -z "${fullPageCachePort}" ]]; then
  fullPageCachePort="${cachePort}"
fi

if [[ -z "${fullPageCacheDatabase}" ]]; then
  fullPageCacheDatabase="1"
fi

if [[ -z "${fullPageCachePassword}" ]]; then
  fullPageCachePassword="${cachePassword}"
fi

if [[ -z "${fullPageCachePrefix}" ]]; then
  fullPageCachePrefix="fpc_"
fi

if [[ -z "${sessionHost}" ]]; then
  sessionHost="${cacheHost}"
fi

if [[ -z "${sessionPort}" ]]; then
  sessionPort="${cachePort}"
fi

if [[ -z "${sessionDatabase}" ]]; then
  sessionDatabase="2"
fi

if [[ -z "${sessionPassword}" ]]; then
  sessionPassword="${cachePassword}"
fi

if [[ ! -f "${appPath}/app/etc/env.php" ]]; then
  >&2 echo "No Magento installation found in: ${appPath}"
  exit 1
fi

runAsUser()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" "$@"
  else
    "$@"
  fi
}

runMagento()
{
  runAsUser php "${appPath}/bin/magento" "$@" 2>&1
}

cd "${appPath}"

magentoVersion=$(runMagento --version | awk '{print $NF}')
echo "Magento version: ${magentoVersion}"

if version-compare "${magentoVersion}" -ge 2.4.9; then
  backend="${cacheType}"
else
  backend="redis"
fi

echo "Using cache backend: ${backend} on: ${cacheHost}:${cachePort} with database: ${cacheDatabase}"
runMagento setup:config:set \
  --no-interaction \
  "--cache-backend=${backend}" \
  "--cache-backend-${backend}-server=${cacheHost}" \
  "--cache-backend-${backend}-port=${cachePort}" \
  "--cache-backend-${backend}-db=${cacheDatabase}" \
  "--cache-backend-${backend}-password=${cachePassword}" \
  "--cache-id-prefix=${cachePrefix}"

echo "Using full page cache backend: ${backend} on: ${fullPageCacheHost}:${fullPageCachePort} with database: ${fullPageCacheDatabase}"
runMagento setup:config:set \
  --no-interaction \
  "--page-cache=${backend}" \
  "--page-cache-${backend}-server=${fullPageCacheHost}" \
  "--page-cache-${backend}-port=${fullPageCachePort}" \
  "--page-cache-${backend}-db=${fullPageCacheDatabase}" \
  "--page-cache-${backend}-password=${fullPageCachePassword}" \
  "--page-cache-id-prefix=${fullPageCachePrefix}"

echo "Using session backend: ${backend} on: ${sessionHost}:${sessionPort} with database: ${sessionDatabase}"
runMagento setup:config:set \
  --no-interaction \
  "--session-save=${backend}" \
  "--session-save-${backend}-host=${sessionHost}" \
  "--session-save-${backend}-port=${sessionPort}" \
  "--session-save-${backend}-db=${sessionDatabase}" \
  "--session-save-${backend}-password=${sessionPassword}"

runMagento cache:clean
