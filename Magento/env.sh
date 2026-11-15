#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Attaches a Magento 2 project to an existing database (e.g. an imported copy of another system) instead of installing
it: writes app/etc/env.php with the encryption key of that system and the database connection, configures the search
engine and RabbitMQ and optionally changes the base URL (cosyses Magento base-url.sh). An existing app/etc/env.php is
kept. Afterwards, build the shop with: cosyses Magento build.sh

usage: ${scriptFileName} options

OPTIONS:
  --help               Show this message
  --appPath            Path of the Magento installation, default: /var/www/magento/htdocs
  --user               System user who owns the installation and runs bin/magento, default: www-data
  --cryptKey           Encryption key of the system the database comes from
  --installDate        Installation date, default: now
  --adminPath          Path of the admin area, default: admin
  --documentRootIsPub  The document root of the web server is the pub directory (true/false), default: true
  --databaseHost       Database host, default: localhost
  --databasePort       Database port, default: 3306
  --databaseUser       Database user
  --databasePassword   Database password
  --databaseName       Database name, default: magento
  --searchEngine       opensearch, elasticsearch7 or elasticsearch8, default: opensearch
  --searchHost         Search engine host, default: localhost
  --searchPort         Search engine port, default: 9200
  --queueHost          RabbitMQ host (AMQP is only configured if a queue user is given), default: localhost
  --queuePort          RabbitMQ port, default: 5672
  --queueUser          RabbitMQ user
  --queuePassword      RabbitMQ password
  --queueVirtualHost   RabbitMQ virtual host, default: /
  --queueSsl           Use SSL for RabbitMQ (true/false), default: false
  --baseUrl            New base URL (optional), for example: https://shop.local/

Example: ${scriptFileName} --cryptKey 0123456789abcdef0123456789abcdef --databaseUser magento --databasePassword secret --baseUrl https://shop.local/
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
cryptKey=
installDate=
adminPath=
documentRootIsPub=
databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
searchEngine=
searchHost=
searchPort=
queueHost=
queuePort=
queueUser=
queuePassword=
queueVirtualHost=
queueSsl=
baseUrl=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${installDate}" ]]; then
  installDate=$(date -R)
fi

if [[ -z "${adminPath}" ]]; then
  adminPath="admin"
fi

if [[ -z "${documentRootIsPub}" ]]; then
  documentRootIsPub="true"
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="localhost"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseName}" ]]; then
  databaseName="magento"
fi

if [[ -z "${searchEngine}" ]]; then
  searchEngine="opensearch"
fi

case "${searchEngine}" in
  opensearch|elasticsearch7|elasticsearch8) ;;
  elasticsearch) searchEngine="elasticsearch7" ;;
  *) >&2 echo "Invalid search engine: ${searchEngine}, use opensearch, elasticsearch7 or elasticsearch8"; usage; exit 1 ;;
esac

if [[ -z "${searchHost}" ]]; then
  searchHost="localhost"
fi

if [[ -z "${searchPort}" ]]; then
  searchPort="9200"
fi

if [[ -z "${queueHost}" ]]; then
  queueHost="localhost"
fi

if [[ -z "${queuePort}" ]]; then
  queuePort="5672"
fi

if [[ -z "${queueVirtualHost}" ]]; then
  queueVirtualHost="/"
fi

if [[ -z "${queueSsl}" ]]; then
  queueSsl="false"
fi

if [[ ! -f "${appPath}/bin/magento" ]]; then
  >&2 echo "No Magento project found in: ${appPath}"
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

envFile="${appPath}/app/etc/env.php"

if [[ -f "${envFile}" ]]; then
  echo "Keeping existing configuration: ${envFile}"
else
  if [[ -z "${cryptKey}" ]]; then
    >&2 echo "No crypt key specified!"
    usage
    exit 1
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

  # Single quotes and backslashes have to be escaped in PHP strings
  phpString()
  {
    local value="${1//\\/\\\\}"
    echo "'${value//\'/\\\'}'"
  }

  # Magento 2.4.8 sets the character set itself and removes the init statement of older versions
  magentoVersion=$(runMagento --version | awk '{print $NF}')
  initStatements=""
  if version-compare "${magentoVersion}" -lt 2.4.8; then
    initStatements=$'\n'"                'initStatements' => 'SET NAMES utf8;',"
  fi

  echo "Creating configuration: ${envFile}"
  cat <<EOF | runAsUser tee "${envFile}" > /dev/null
<?php
return [
    'backend' => [
        'frontName' => $(phpString "${adminPath}")
    ],
    'crypt' => [
        'key' => $(phpString "${cryptKey}")
    ],
    'db' => [
        'table_prefix' => '',
        'connection' => [
            'default' => [
                'host' => $(phpString "${databaseHost}:${databasePort}"),
                'dbname' => $(phpString "${databaseName}"),
                'username' => $(phpString "${databaseUser}"),
                'password' => $(phpString "${databasePassword}"),
                'model' => 'mysql4',
                'engine' => 'innodb',${initStatements}
                'active' => '1',
                'driver_options' => [
                    1014 => false
                ]
            ]
        ]
    ],
    'resource' => [
        'default_setup' => [
            'connection' => 'default'
        ]
    ],
    'x-frame-options' => 'SAMEORIGIN',
    'MAGE_MODE' => 'default',
    'session' => [
        'save' => 'files'
    ],
    'lock' => [
        'provider' => 'db'
    ],
    'directories' => [
        'document_root_is_pub' => ${documentRootIsPub}
    ],
    'install' => [
        'date' => $(phpString "${installDate}")
    ]
];
EOF
  runAsUser chmod 640 "${envFile}"
fi

echo "Enabling all cache types"
runMagento cache:enable

echo "Using search engine: ${searchEngine} on: ${searchHost}:${searchPort}"
runMagento config:set --lock-env catalog/search/engine "${searchEngine}"
runMagento config:set --lock-env "catalog/search/${searchEngine}_server_hostname" "${searchHost}"
runMagento config:set --lock-env "catalog/search/${searchEngine}_server_port" "${searchPort}"

if [[ -n "${queueUser}" ]]; then
  echo "Using RabbitMQ on: ${queueHost}:${queuePort}"
  runMagento setup:config:set \
    --no-interaction \
    "--amqp-host=${queueHost}" \
    "--amqp-port=${queuePort}" \
    "--amqp-user=${queueUser}" \
    "--amqp-password=${queuePassword}" \
    "--amqp-virtualhost=${queueVirtualHost}" \
    "--amqp-ssl=${queueSsl}"
fi

if [[ -n "${baseUrl}" ]]; then
  cosyses \
    --applicationName Magento \
    --applicationScript base-url.sh \
    --appPath "${appPath}" \
    --user "${user}" \
    --baseUrl "${baseUrl}"
fi

runMagento cache:clean
