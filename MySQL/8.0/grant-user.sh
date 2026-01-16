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
  --databaseName          Database name to grant the user rights to (required if create database or grant database)
  --databaseRootUser      Root user, default: root
  --databaseRootPassword  Root password

Example: ${scriptName} --databaseUser newuser --databasePassword password --databaseName database --databaseRootPassword secret --createDatabase yes
EOF
}

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  exit 1
fi

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

databaseHost=
databasePort=
databaseUser=
databaseName=
databaseRootUser=
databaseRootPassword=
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

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  echo "No database root password specified!"
  usage
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  usage
  exit 1
fi

userNames=( "'${databaseUser}'@'%'" "'${databaseUser}'@'127.0.0.1'" "'${databaseUser}'@'localhost'" )

export MYSQL_PWD="${databaseRootPassword}"

for userName in "${userNames[@]}"; do
  echo "Granting all rights to user: ${userName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO ${userName} WITH GRANT OPTION;"
done

echo "Flushing privileges"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "FLUSH PRIVILEGES;"
