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
  --databaseRootUser      Root user, default: root
  --databaseRootPassword  Root password
  --grantSuperRights      Grant user super rights, default: no
  --createDatabase        Create initial database, default: no

Example: ${scriptName} -u newuser -s password -b database -t mysql -v 5.7 -w secret
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
databaseRootUser=
databaseRootPassword=
grantSuperRights=
createDatabase=
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

if [[ -z "${createDatabase}" ]]; then
  createDatabase="no"
fi

userNames=( "'${databaseUser}'@'%'" "'${databaseUser}'@'127.0.0.1'" "'${databaseUser}'@'localhost'" )

export MYSQL_PWD="${databaseRootPassword}"

for userName in "${userNames[@]}"; do
  echo "Adding user: ${userName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "CREATE USER ${userName} IDENTIFIED BY '${databasePassword}';"

  echo "Granting all rights to user: ${userName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO ${userName} WITH GRANT OPTION;"

  if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: ${userName}"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO ${userName};"
  fi
done

echo "Flushing privileges"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "FLUSH PRIVILEGES;"

if [[ "${createDatabase}" == "yes" ]]; then
  export MYSQL_PWD="${databasePassword}"

  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS ${databaseName};"

  echo "Creating database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "CREATE DATABASE ${databaseName} CHARACTER SET utf8 COLLATE utf8_general_ci;";
fi
