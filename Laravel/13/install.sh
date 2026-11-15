#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Creates a Laravel 13 project (laravel/laravel with laravel/framework 13) in a directory, or installs its dependencies
if it exists, sets the database, cache, session, Redis and mail settings in its .env, generates the application key if
missing and migrates the database. PHP (cosyses PHP 8.4 laravel.sh) and Composer have to be installed; the database
server has to be running and the database and its user have to exist (cosyses MariaDB <version> create-user.sh).

usage: ${scriptFileName} options

OPTIONS:
  --help                Show this message
  --appPath             Directory of the project
  --user                System user who owns the project and runs the commands, default: www-data
  --laravelVersion      Version or constraint of laravel/framework for a new project, default: ^13.0
                        The skeleton laravel/laravel is created with <major>.* of it.
                        Tested: ^13.0 and ^12.0 (PHP 8.4), older versions are untested
  --appName            Name of the application, default: Laravel
  --appUrl              URL of the application, default: http://localhost
  --appEnv              Environment, default: production
  --appDebug            Debug mode (true or false), default: false
  --databaseConnection  Database driver (mysql, mariadb, pgsql or sqlite), default: mysql
  --databaseHost        Database host, default: 127.0.0.1
  --databasePort        Database port, default: 3306
  --databaseName        Database name (the file with sqlite), default: laravel
  --databaseUser        Database user (not with sqlite)
  --databasePassword    Database password (not with sqlite)
  --cacheStore          Cache store (database, file, redis, ...), default: database
  --sessionDriver       Session driver (database, file, redis, ...), default: database
  --queueConnection     Queue connection (database, sync, redis, ...), default: database
  --redisHost           Host of Redis or Valkey, default: 127.0.0.1
  --redisPort           Port of Redis or Valkey, default: 6379
  --mailMailer          Mailer (log, smtp, ...), default: log
  --mailHost            SMTP host, default: 127.0.0.1
  --mailPort            SMTP port, default: 1025
  --mailFromAddress     Sender address, default: webserver@<host of the URL>
  --migrate             Migrate the database (yes/no), default: yes

Example: ${scriptFileName} --appPath /var/www/laravel --appUrl https://app.example.com --databaseUser laravel --databasePassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
laravelVersion=
appName=
appUrl=
appEnv=
appDebug=
databaseConnection=
databaseHost=
databasePort=
databaseName=
databaseUser=
databasePassword=
cacheStore=
sessionDriver=
queueConnection=
redisHost=
redisPort=
mailMailer=
mailHost=
mailPort=
mailFromAddress=
migrate=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${laravelVersion}" ]]; then
  laravelVersion="^13.0"
fi

# The skeleton has the same major version as the framework
laravelMajorVersion=$(echo "${laravelVersion}" | grep -oE '[0-9]+' | head -n 1)
if [[ -z "${laravelMajorVersion}" ]]; then
  >&2 echo "Invalid Laravel version: ${laravelVersion}"
  usage
  exit 1
fi

if [[ -z "${appName}" ]]; then
  appName="Laravel"
fi

if [[ -z "${appUrl}" ]]; then
  appUrl="http://localhost"
fi

if [[ -z "${appEnv}" ]]; then
  appEnv="production"
fi

if [[ -z "${appDebug}" ]]; then
  appDebug="false"
fi

if [[ -z "${databaseConnection}" ]]; then
  databaseConnection="mysql"
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  if [[ "${databaseConnection}" == "pgsql" ]]; then
    databasePort="5432"
  else
    databasePort="3306"
  fi
fi

if [[ -z "${databaseName}" ]]; then
  databaseName="laravel"
fi

if [[ "${databaseConnection}" != "sqlite" ]]; then
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
fi

if [[ -z "${cacheStore}" ]]; then
  cacheStore="database"
fi

if [[ -z "${sessionDriver}" ]]; then
  sessionDriver="database"
fi

if [[ -z "${queueConnection}" ]]; then
  queueConnection="database"
fi

if [[ -z "${redisHost}" ]]; then
  redisHost="127.0.0.1"
fi

if [[ -z "${redisPort}" ]]; then
  redisPort="6379"
fi

if [[ -z "${mailMailer}" ]]; then
  mailMailer="log"
fi

if [[ -z "${mailHost}" ]]; then
  mailHost="127.0.0.1"
fi

if [[ -z "${mailPort}" ]]; then
  mailPort="1025"
fi

if [[ -z "${mailFromAddress}" ]]; then
  appHostName="${appUrl#*://}"
  appHostName="${appHostName%%[:/]*}"
  mailFromAddress="webserver@${appHostName}"
fi

if [[ -z "${migrate}" ]]; then
  migrate="yes"
fi

if ! id "${user}" > /dev/null 2>&1; then
  >&2 echo "User: ${user} does not exist!"
  exit 1
fi

if [[ ! -x "$(command -v php)" ]]; then
  >&2 echo "PHP not found, install it first (cosyses PHP 8.4 and cosyses PHP 8.4 laravel.sh)"
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

# The project scripts are not run, they would generate the key and migrate a SQLite database before the settings exist
cosyses \
  --applicationName Composer \
  --applicationScript create-project.sh \
  --packageName laravel/laravel \
  --packageVersion "${laravelMajorVersion}.*" \
  --requirePackages "laravel/framework:${laravelVersion}" \
  --noScripts yes \
  --removeVcs yes \
  --appPath "${appPath}" \
  --binaries artisan \
  --user "${user}"

cd "${appPath}"

envFile="${appPath}/.env"
if [[ ! -f "${envFile}" ]]; then
  echo "Creating: ${envFile}"
  if [[ -f "${appPath}/.env.example" ]]; then
    cp "${appPath}/.env.example" "${envFile}"
  else
    touch "${envFile}"
  fi
fi

echo "Writing settings to: ${envFile}"
setEnvValue "${envFile}" APP_NAME "${appName}"
setEnvValue "${envFile}" APP_ENV "${appEnv}"
setEnvValue "${envFile}" APP_DEBUG "${appDebug}"
setEnvValue "${envFile}" APP_URL "${appUrl}"
setEnvValue "${envFile}" DB_CONNECTION "${databaseConnection}"
if [[ "${databaseConnection}" == "sqlite" ]]; then
  if [[ "${databaseName}" != /* ]]; then
    databaseName="${appPath}/database/${databaseName}.sqlite"
  fi
  setEnvValue "${envFile}" DB_DATABASE "${databaseName}"
  if [[ ! -f "${databaseName}" ]]; then
    echo "Creating SQLite database: ${databaseName}"
    runAsUser touch "${databaseName}"
  fi
else
  setEnvValue "${envFile}" DB_HOST "${databaseHost}"
  setEnvValue "${envFile}" DB_PORT "${databasePort}"
  setEnvValue "${envFile}" DB_DATABASE "${databaseName}"
  setEnvValue "${envFile}" DB_USERNAME "${databaseUser}"
  setEnvValue "${envFile}" DB_PASSWORD "${databasePassword}"
fi
setEnvValue "${envFile}" CACHE_STORE "${cacheStore}"
setEnvValue "${envFile}" SESSION_DRIVER "${sessionDriver}"
setEnvValue "${envFile}" QUEUE_CONNECTION "${queueConnection}"
setEnvValue "${envFile}" REDIS_CLIENT phpredis
setEnvValue "${envFile}" REDIS_HOST "${redisHost}"
setEnvValue "${envFile}" REDIS_PORT "${redisPort}"
setEnvValue "${envFile}" MAIL_MAILER "${mailMailer}"
setEnvValue "${envFile}" MAIL_HOST "${mailHost}"
setEnvValue "${envFile}" MAIL_PORT "${mailPort}"
setEnvValue "${envFile}" MAIL_FROM_ADDRESS "${mailFromAddress}"

chown "${user}": "${envFile}"
chmod 0640 "${envFile}"

if ! grep -qE "^APP_KEY=.+" "${envFile}"; then
  echo "Generating application key"
  runAsUser php artisan key:generate --force --no-interaction
fi

if [[ "${migrate}" == "yes" ]]; then
  echo "Migrating database"
  runAsUser php artisan migrate --force --no-interaction
fi
