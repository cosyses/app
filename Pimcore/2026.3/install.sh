#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Creates a Pimcore 2026.3 project (pimcore/skeleton) in a directory, or installs its dependencies if it exists, writes
the database, OpenSearch, RabbitMQ and Mercure settings to .env.local and installs Pimcore with vendor/bin/pimcore-install.
The installation needs a product key, which is registered for the encryption secret and instance identifier of the
installation (https://license.pimcore.com/register). Without a product key, the project is created and configured
(with a generated encryption secret and instance identifier in .env.local) and the registration URL is printed; run
the script again with --productKey afterwards. PHP (cosyses PHP 8.4 pimcore.sh) and Composer have to be installed;
the database server, OpenSearch, RabbitMQ and Mercure have to be running and the database and its user have to exist
(cosyses MariaDB <version> create-user.sh). If Pimcore is already installed, the installation is skipped.

usage: ${scriptFileName} options

OPTIONS:
  --help                Show this message
  --appPath             Directory of the project
  --user                System user who owns the project and runs the commands, default: www-data
  --appEnv              Environment (prod or dev), default: prod
  --productKey          Pimcore product key, without it Pimcore is not installed
  --encryptionSecret    Encryption secret the product key was registered for, default: <generated once>
  --instanceIdentifier  Instance identifier the product key was registered for, default: <generated once>
  --databaseHost      Database host, default: localhost
  --databasePort      Database port, default: 3306
  --databaseName      Database name, default: pimcore
  --databaseUser      Database user
  --databasePassword  Database password
  --adminUser         Name of the admin user, default: admin
  --adminPassword     Password of the admin user, default: <generated and printed>
  --searchHost        Host of OpenSearch, default: localhost
  --searchPort        Port of OpenSearch, default: 9200
  --searchScheme      Scheme of OpenSearch (http or https), default: http
  --searchUser        OpenSearch user, default: none
  --searchPassword    OpenSearch password, default: none
  --queueHost         Host of RabbitMQ, default: localhost
  --queuePort         Port of RabbitMQ, default: 5672
  --queueUser         RabbitMQ user, default: guest
  --queuePassword     RabbitMQ password, default: guest
  --mercureUrl        Public URL of the Mercure hub, default: http://localhost/hub
  --mercureServerUrl  Internal URL of the Mercure hub, default: http://localhost:3000/.well-known/mercure

Example: ${scriptFileName} --appPath /var/www/pimcore --productKey <key> --databaseUser pimcore --databasePassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
appEnv=
productKey=
encryptionSecret=
instanceIdentifier=
databaseHost=
databasePort=
databaseName=
databaseUser=
databasePassword=
adminUser=
adminPassword=
searchHost=
searchPort=
searchScheme=
searchUser=
searchPassword=
queueHost=
queuePort=
queueUser=
queuePassword=
mercureUrl=
mercureServerUrl=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
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
  databaseName="pimcore"
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

if [[ -z "${adminUser}" ]]; then
  adminUser="admin"
fi

if [[ -z "${searchHost}" ]]; then
  searchHost="localhost"
fi

if [[ -z "${searchPort}" ]]; then
  searchPort="9200"
fi

if [[ -z "${searchScheme}" ]]; then
  searchScheme="http"
fi

if [[ -z "${queueHost}" ]]; then
  queueHost="localhost"
fi

if [[ -z "${queuePort}" ]]; then
  queuePort="5672"
fi

if [[ -z "${queueUser}" ]]; then
  queueUser="guest"
fi

if [[ -z "${queuePassword}" ]]; then
  queuePassword="guest"
fi

if [[ -z "${mercureUrl}" ]]; then
  mercureUrl="http://localhost/hub"
fi

if [[ -z "${mercureServerUrl}" ]]; then
  mercureServerUrl="http://localhost:3000/.well-known/mercure"
fi

if ! id "${user}" > /dev/null 2>&1; then
  >&2 echo "User: ${user} does not exist!"
  exit 1
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP 8.4 and cosyses PHP 8.4 pimcore.sh)"
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

# The project scripts need the installed Pimcore, the README of the skeleton also creates it without them
cosyses \
  --applicationName Composer \
  --applicationScript create-project.sh \
  --packageName pimcore/skeleton \
  --packageVersion "2026.3.*" \
  --noScripts yes \
  --appPath "${appPath}" \
  --binaries bin/console,vendor/bin/pimcore-install \
  --user "${user}"

cd "${appPath}"

envFile="${appPath}/.env.local"
echo "Writing settings to: ${envFile}"

searchCredentials=
if [[ -n "${searchUser}" ]]; then
  searchCredentials="$(urlEncode "${searchUser}"):$(urlEncode "${searchPassword}")@"
fi
# Pimcore uses SSL if the DSN does not disable it
if [[ "${searchScheme}" == "https" ]]; then
  searchOptions="?ssl=true&ssl_verify=false"
else
  searchOptions="?ssl=false"
fi

setEnvValue "${envFile}" APP_ENV "${appEnv}"
setEnvValue "${envFile}" DATABASE_URL "mysql://$(urlEncode "${databaseUser}"):$(urlEncode "${databasePassword}")@${databaseHost}:${databasePort}/${databaseName}"
setEnvValue "${envFile}" PIMCORE_OPENSEARCH_DSN "opensearch://${searchCredentials}${searchHost}:${searchPort}${searchOptions}"
setEnvValue "${envFile}" PIMCORE_MESSENGER_TRANSPORT_DSN_PREFIX "amqp://$(urlEncode "${queueUser}"):$(urlEncode "${queuePassword}")@${queueHost}:${queuePort}/%2f/"
setEnvValue "${envFile}" MERCURE_URL "${mercureUrl}"
setEnvValue "${envFile}" MERCURE_SERVER_URL "${mercureServerUrl}"
if [[ -z "$(getEnvValue "${envFile}" APPLICATION_SECRET)" ]]; then
  setEnvValue "${envFile}" APPLICATION_SECRET "$(php -r 'echo bin2hex(random_bytes(32));')"
fi
if [[ -z "$(getEnvValue "${envFile}" MERCURE_JWT_KEY)" ]]; then
  setEnvValue "${envFile}" MERCURE_JWT_KEY "$(php -r 'echo bin2hex(random_bytes(32));')"
fi

# The product key is registered for the encryption secret and the instance identifier, they are generated only once
if [[ -n "${encryptionSecret}" ]]; then
  setEnvValue "${envFile}" PIMCORE_ENCRYPTION_SECRET "${encryptionSecret}"
elif [[ -z "$(getEnvValue "${envFile}" PIMCORE_ENCRYPTION_SECRET)" ]]; then
  setEnvValue "${envFile}" PIMCORE_ENCRYPTION_SECRET "$(runAsUser php vendor/bin/generate-defuse-key)"
fi
if [[ -n "${instanceIdentifier}" ]]; then
  setEnvValue "${envFile}" PIMCORE_INSTANCE_IDENTIFIER "${instanceIdentifier}"
elif [[ -z "$(getEnvValue "${envFile}" PIMCORE_INSTANCE_IDENTIFIER)" ]]; then
  # shellcheck disable=SC2016
  setEnvValue "${envFile}" PIMCORE_INSTANCE_IDENTIFIER "$(php -r 'require $argv[1]; echo Symfony\Component\Uid\Uuid::v6()->toBase58();' -- "${appPath}/vendor/autoload.php")"
fi
if [[ -n "${productKey}" ]]; then
  setEnvValue "${envFile}" PIMCORE_PRODUCT_KEY "${productKey}"
fi

chown "${user}": "${envFile}"
chmod 0640 "${envFile}"

if [[ ! -f "${appPath}/var/config/needs-install.lock" ]]; then
  echo "Pimcore is already installed (no var/config/needs-install.lock)"
  exit 0
fi

if [[ -z "$(getEnvValue "${envFile}" PIMCORE_PRODUCT_KEY)" ]]; then
  # shellcheck disable=SC2016
  instanceHash=$(php -r 'echo hash_hmac("sha256", $argv[1], $argv[2]);' -- "$(getEnvValue "${envFile}" PIMCORE_INSTANCE_IDENTIFIER)" "$(getEnvValue "${envFile}" PIMCORE_ENCRYPTION_SECRET)")
  echo "No product key specified, Pimcore is not installed. Register the installation to obtain a product key:"
  echo "https://license.pimcore.com/register?instance_identifier=$(getEnvValue "${envFile}" PIMCORE_INSTANCE_IDENTIFIER)&instance_hash=${instanceHash}"
  echo "Then run this script again with: --productKey <key>"
  exit 0
fi

if [[ -z "${adminPassword}" ]]; then
  adminPassword=$(php -r 'echo bin2hex(random_bytes(8));')
  echo "Using generated admin password: ${adminPassword}"
fi

echo "Installing Pimcore"
runAsUser php vendor/bin/pimcore-install \
  --install-profile='App\Installer\SkeletonProfile' \
  --admin-username "${adminUser}" \
  --admin-password "${adminPassword}" \
  --no-interaction
