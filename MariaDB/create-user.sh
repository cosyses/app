#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                   Show this message
  --databaseRootUser       Root user, default: root
  --databaseRootPassword   Root password
  --databaseHost           Database host, default: 127.0.0.1
  --databasePort           Database port, default: 3306
  --databaseUser           Name of the database user to create
  --databasePassword       Database password of the user to create
  --databaseName           Database name to grant the user rights to (required if create database or grant database)
  --grantSuperRights       Grant user super rights, default: no
  --grantDatabaseRights    Grant rights to database, default: no
  --createInitialDatabase  Create initial database, default: no

Example: ${scriptName} --databaseRootPassword secret --databaseUser user --databasePassword password --databaseName database --createInitialDatabase yes
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

databaseRootUser=
databaseRootPassword=
databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
grantSuperRights=
grantDatabaseRights=
createInitialDatabase=
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

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  echo "No database root password specified!"
  usage
  exit 1
fi

if [[ -z "${grantSuperRights}" ]]; then
  grantSuperRights="no"
fi

if [[ -z "${grantDatabaseRights}" ]]; then
  grantDatabaseRights="no"
fi

if [[ -z "${createInitialDatabase}" ]]; then
  createInitialDatabase="no"
fi

if { [[ "${grantDatabaseRights}" == "yes" ]] || [[ "${createInitialDatabase}" == "yes" ]]; } && [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  usage
  exit 1
fi

export MYSQL_PWD="${databaseRootPassword}"

userNames=( "'${databaseUser}'@'%'" "'${databaseUser}'@'127.0.0.1'" "'${databaseUser}'@'localhost'" )

for userName in "${userNames[@]}"; do
  echo "Adding user: ${userName}"
  mariadb -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "CREATE USER ${userName} IDENTIFIED BY '${databasePassword}';"
done

echo "Flushing privileges"
mariadb -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "FLUSH PRIVILEGES;"

if [[ "${grantDatabaseRights}" == "yes" ]] || [[ "${createInitialDatabase}" == "yes" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --applicationScript "grant-user.sh" \
    --databaseHost "${databaseHost}" \
    --databasePort "${databasePort}" \
    --databaseUser "${databaseUser}" \
    --databaseName "${databaseName}" \
    --databaseRootUser "${databaseRootUser}" \
    --databaseRootPassword "${databaseRootPassword}"
fi

if [[ "${grantSuperRights}" == "yes" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --applicationScript "grant-super.sh" \
    --databaseHost "${databaseHost}" \
    --databasePort "${databasePort}" \
    --databaseUser "${databaseUser}" \
    --databaseName "${databaseName}" \
    --databaseRootUser "${databaseRootUser}" \
    --databaseRootPassword "${databaseRootPassword}"
fi

if [[ "${createInitialDatabase}" == "yes" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --applicationScript "create-database.sh" \
    --databaseHost "${databaseHost}" \
    --databasePort "${databasePort}" \
    --databaseUser "${databaseUser}" \
    --databasePassword "${databasePassword}" \
    --databaseName "${databaseName}"
fi
