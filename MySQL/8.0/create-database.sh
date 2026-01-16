#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                  Show this message
  --databaseHost          Database host, default: 127.0.0.1
  --databasePort          Database port, default: 3306
  --databaseUser          Name of the database user to create
  --databasePassword      Database password of the user to create
  --databaseName          Database name to grant the user rights to

Example: ${scriptName} --databaseUser newuser --databasePassword password --databaseName database
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${databaseHost}" ]] || [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort=3306
fi

if [[ -z "${databaseUser}" ]]; then
  echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  usage
  exit 1
fi

export MYSQL_PWD="${databasePassword}"

echo "Dropping database: ${databaseName}"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS ${databaseName};"

echo "Creating database: ${databaseName}"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "CREATE DATABASE ${databaseName} CHARACTER SET utf8 COLLATE utf8_general_ci;";
