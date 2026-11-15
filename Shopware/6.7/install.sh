#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Creates a Shopware 6.7 project (shopware/production) in a directory, writes its settings to .env.local and installs
the shop with an admin user and a storefront sales channel. The database server has to be running and the database
user has to exist (cosyses MariaDB <version> create-user.sh). PHP (cosyses PHP 8.4 shopware.sh) and Composer have to
be installed. If the shop is already installed (install.lock), only the settings are written.

usage: ${scriptFileName} options

OPTIONS:
  --help              Show this message
  --appPath           Directory of the project
  --user              System user who owns the project and runs the commands, default: www-data
  --appUrl            URL of the shop and its storefront sales channel, default: http://localhost
  --appEnv            Environment (prod or dev), default: prod
  --databaseHost      Database host, default: localhost
  --databasePort      Database port, default: 3306
  --databaseName      Database name, default: shopware
  --databaseUser      Database user
  --databasePassword  Database password
  --shopName          Name of the shop and its storefront sales channel, default: Storefront
  --shopEmail         Email address of the shop, default: Shopware default
  --shopLocale        Default locale of the shop, default: en-GB
  --shopCurrency      Default currency of the shop, default: EUR
  --adminUser         Name of the admin user, default: admin
  --adminPassword     Password of the admin user, default: <generated and printed>
  --adminFirstName    First name of the admin user, default: Admin
  --adminLastName     Last name of the admin user, default: Admin
  --adminEmail        Email address of the admin user, default: admin@example.com
  --searchEngine      Search engine to use (none or opensearch), default: none
  --searchHost        Host of OpenSearch, default: localhost
  --searchPort        Port of OpenSearch, default: 9200
  --searchIndexPrefix Prefix of the search indices, default: sw
  --cacheType         Cache and session storage (none or redis), default: none
  --cacheHost         Host of Redis or Valkey, default: localhost
  --cachePort         Port of Redis or Valkey, default: 6379
  --cacheDatabase     Redis database of the cache, default: 0
  --sessionDatabase   Redis database of the sessions, default: 1
  --securityBlocking  Let Composer refuse package versions with security advisories (yes/no), default: no, because
                      Shopware releases often depend on packages with open advisories

Example: ${scriptFileName} --appPath /var/www/shop --appUrl https://shop.example.com --databaseUser shopware --databasePassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
appUrl=
appEnv=
databaseHost=
databasePort=
databaseName=
databaseUser=
databasePassword=
shopName=
shopEmail=
shopLocale=
shopCurrency=
adminUser=
adminPassword=
adminFirstName=
adminLastName=
adminEmail=
searchEngine=
searchHost=
searchPort=
searchIndexPrefix=
cacheType=
cacheHost=
cachePort=
cacheDatabase=
sessionDatabase=
securityBlocking=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${securityBlocking}" ]]; then
  securityBlocking="no"
fi

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${appUrl}" ]]; then
  appUrl="http://localhost"
fi

if [[ -z "${appEnv}" ]]; then
  appEnv="prod"
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="localhost"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseName}" ]]; then
  databaseName="shopware"
fi

if [[ -z "${databaseUser}" ]]; then
  >&2 echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  >&2 echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${shopName}" ]]; then
  shopName="Storefront"
fi

if [[ -z "${shopLocale}" ]]; then
  shopLocale="en-GB"
fi

if [[ -z "${shopCurrency}" ]]; then
  shopCurrency="EUR"
fi

if [[ -z "${adminUser}" ]]; then
  adminUser="admin"
fi

if [[ -z "${adminFirstName}" ]]; then
  adminFirstName="Admin"
fi

if [[ -z "${adminLastName}" ]]; then
  adminLastName="Admin"
fi

if [[ -z "${adminEmail}" ]]; then
  adminEmail="admin@example.com"
fi

if [[ -z "${searchEngine}" ]]; then
  searchEngine="none"
fi

if [[ "${searchEngine}" != "none" ]] && [[ "${searchEngine}" != "opensearch" ]]; then
  >&2 echo "Invalid search engine: ${searchEngine}, use none or opensearch"
  usage
  exit 1
fi

if [[ -z "${searchHost}" ]]; then
  searchHost="localhost"
fi

if [[ -z "${searchPort}" ]]; then
  searchPort="9200"
fi

if [[ -z "${searchIndexPrefix}" ]]; then
  searchIndexPrefix="sw"
fi

if [[ -z "${cacheType}" ]]; then
  cacheType="none"
fi

if [[ "${cacheType}" != "none" ]] && [[ "${cacheType}" != "redis" ]]; then
  >&2 echo "Invalid cache type: ${cacheType}, use none or redis"
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

if [[ -z "${sessionDatabase}" ]]; then
  sessionDatabase="1"
fi

if ! id "${user}" > /dev/null 2>&1; then
  >&2 echo "User: ${user} does not exist!"
  exit 1
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP 8.4 and cosyses PHP 8.4 shopware.sh)"
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

# Sets a variable in an env file, replaces an existing (or commented) definition or adds it
setEnvValue()
{
  local envFile="${1}"
  local key="${2}"
  local value="${3}"
  local pattern

  if [[ ! "${value}" =~ ^[A-Za-z0-9_./:@%+=,~-]*$ ]]; then
    if [[ "${value}" == *"'"* ]]; then
      >&2 echo "Value of ${key} must not contain a single quote!"
      exit 1
    fi
    value="'${value}'"
  fi

  touch "${envFile}"
  if grep -qE "^${key}=" "${envFile}"; then
    pattern="^${key}="
  elif grep -qE "^# ?${key}=" "${envFile}"; then
    pattern="^# ?${key}="
  else
    echo "${key}=${value}" >> "${envFile}"
    return
  fi

  ENV_KEY="${key}" ENV_VALUE="${value}" ENV_PATTERN="${pattern}" awk '
    BEGIN { key = ENVIRON["ENV_KEY"]; value = ENVIRON["ENV_VALUE"]; pattern = ENVIRON["ENV_PATTERN"]; done = 0 }
    $0 ~ pattern && (done == 0 || pattern !~ /#/) { print key "=" value; done = 1; next }
    { print }
  ' "${envFile}" > "${envFile}.tmp"
  cat "${envFile}.tmp" > "${envFile}"
  rm -f "${envFile}.tmp"
}

# Reads a variable from an env file
getEnvValue()
{
  if [[ -f "${1}" ]]; then
    grep -E "^${2}=" "${1}" | tail -n 1 | cut -d= -f2- | sed -e "s/^['\"]//" -e "s/['\"]$//"
  fi
}

urlEncode()
{
  # shellcheck disable=SC2016
  php -r 'echo rawurlencode($argv[1]);' -- "${1}"
}

cosyses \
  --applicationName Composer \
  --applicationScript create-project.sh \
  --packageName shopware/production \
  --packageVersion "6.7.*" \
  --appPath "${appPath}" \
  --binaries bin/console \
  --securityBlocking "${securityBlocking}" \
  --user "${user}"

cd "${appPath}"

envFile="${appPath}/.env.local"
echo "Writing settings to: ${envFile}"

setEnvValue "${envFile}" APP_ENV "${appEnv}"
setEnvValue "${envFile}" APP_URL "${appUrl}"
setEnvValue "${envFile}" DATABASE_URL "mysql://$(urlEncode "${databaseUser}"):$(urlEncode "${databasePassword}")@${databaseHost}:${databasePort}/${databaseName}"
if [[ -z "$(getEnvValue "${envFile}" APP_SECRET)" ]]; then
  setEnvValue "${envFile}" APP_SECRET "$(php -r 'echo bin2hex(random_bytes(64));')"
fi
if [[ -z "$(getEnvValue "${envFile}" INSTANCE_ID)" ]]; then
  setEnvValue "${envFile}" INSTANCE_ID "$(php -r 'echo bin2hex(random_bytes(16));')"
fi
setEnvValue "${envFile}" LOCK_DSN flock
setEnvValue "${envFile}" BLUE_GREEN_DEPLOYMENT 0
setEnvValue "${envFile}" SHOPWARE_HTTP_CACHE_ENABLED 1
setEnvValue "${envFile}" SHOPWARE_HTTP_DEFAULT_TTL 7200

if [[ "${searchEngine}" == "opensearch" ]]; then
  setEnvValue "${envFile}" OPENSEARCH_URL "http://${searchHost}:${searchPort}"
  setEnvValue "${envFile}" SHOPWARE_ES_ENABLED 1
  setEnvValue "${envFile}" SHOPWARE_ES_INDEXING_ENABLED 1
  setEnvValue "${envFile}" SHOPWARE_ES_INDEX_PREFIX "${searchIndexPrefix}"
  setEnvValue "${envFile}" SHOPWARE_ES_THROW_EXCEPTION 1

  searchConfigFile="${appPath}/config/packages/cosyses-elasticsearch.yaml"
  if [[ ! -f "${searchConfigFile}" ]]; then
    echo "Writing OpenSearch configuration to: ${searchConfigFile}"
    cat <<EOF > "${searchConfigFile}"
elasticsearch:
    index_settings:
        number_of_shards: 1
        number_of_replicas: 0
EOF
    chown "${user}": "${searchConfigFile}"
  fi
else
  setEnvValue "${envFile}" SHOPWARE_ES_ENABLED 0
  setEnvValue "${envFile}" SHOPWARE_ES_INDEXING_ENABLED 0
fi

if [[ "${cacheType}" == "redis" ]]; then
  setEnvValue "${envFile}" REDIS_CACHE_DSN "redis://${cacheHost}:${cachePort}/${cacheDatabase}"
  setEnvValue "${envFile}" REDIS_SESSION_DSN "redis://${cacheHost}:${cachePort}/${sessionDatabase}"

  cacheConfigFile="${appPath}/config/packages/cosyses-redis.yaml"
  if [[ ! -f "${cacheConfigFile}" ]]; then
    echo "Writing Redis configuration to: ${cacheConfigFile}"
    cat <<EOF > "${cacheConfigFile}"
framework:
    cache:
        app: cache.adapter.redis
        default_redis_provider: "%env(string:REDIS_CACHE_DSN)%"
    session:
        handler_id: "%env(string:REDIS_SESSION_DSN)%"
EOF
    chown "${user}": "${cacheConfigFile}"
  fi
fi

chown "${user}": "${envFile}"
chmod 0640 "${envFile}"

if [[ -f "${appPath}/install.lock" ]]; then
  echo "Shopware is already installed (install.lock exists)"
  runAsUser php bin/console cache:clear --no-interaction
  exit 0
fi

if [[ -z "${adminPassword}" ]]; then
  adminPassword=$(php -r 'echo bin2hex(random_bytes(8));')
  echo "Using generated admin password: ${adminPassword}"
fi

installArguments=( --create-database --skip-first-run-wizard --no-interaction --shop-name "${shopName}" --shop-locale "${shopLocale}" --shop-currency "${shopCurrency}" )
if [[ -n "${shopEmail}" ]]; then
  installArguments+=( --shop-email "${shopEmail}" )
fi

echo "Installing Shopware"
runAsUser php bin/console system:install "${installArguments[@]}"

echo "Creating admin user: ${adminUser}"
runAsUser php bin/console user:create --admin --no-interaction \
  --password "${adminPassword}" \
  --firstName "${adminFirstName}" \
  --lastName "${adminLastName}" \
  --email "${adminEmail}" \
  "${adminUser}"

echo "Creating storefront sales channel: ${shopName} with URL: ${appUrl}"
runAsUser php bin/console sales-channel:create:storefront --no-interaction \
  --name "${shopName}" \
  --url "${appUrl}" \
  --isoCode "${shopLocale}"

echo "Assigning theme"
runAsUser php bin/console theme:change --all --sync --no-interaction Storefront

if [[ "${searchEngine}" == "opensearch" ]]; then
  echo "Indexing"
  runAsUser php bin/console es:index --no-queue --no-interaction
fi

runAsUser php bin/console cache:clear --no-interaction
