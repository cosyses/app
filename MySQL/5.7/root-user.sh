#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help                  Show this message
  --databaseRootHost      Server host name, default: localhost
  --databaseRootPort      Server port, default: 3306
  --databaseRootPassword  User password, default: <generated>

Example: ${scriptName} --databaseRootPassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

databaseRootHost=
databaseRootPort=
databaseRootPassword=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${databaseRootHost}" ]]; then
  databaseRootHost="localhost"
fi

if [[ -z "${databaseRootPort}" ]]; then
  databaseRootPort="3306"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  databaseRootPassword=$(echo "${RANDOM}" | md5sum | head -c 32)
  echo "Using generated password: ${databaseRootPassword}"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  echo "No database root user specified!"
  exit 1
fi

echo "Adding user: root"
mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e 'use mysql;' >/dev/null 2>&1 && mysqladmin -h"${databaseRootHost}" -P"${databaseRootPort}" -u root password "${databaseRootPassword}" >/dev/null 2>&1

export MYSQL_PWD="${databaseRootPassword}"

rootUserNames=( "'root'@'%'" "'root'@'127.0.0.1'" "'root'@'localhost'" )

for rootUserName in "${rootUserNames[@]}"; do
  echo "Granting super rights to user: ${rootUserName}"
  mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "GRANT USAGE ON *.* TO ${rootUserName} IDENTIFIED BY '${databaseRootPassword}';";

  echo "Granting all privileges to user: ${rootUserName}"
  mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "GRANT ALL PRIVILEGES ON *.* TO ${rootUserName} WITH GRANT OPTION;"

  echo "Allowing login with password to user: ${rootUserName}"
  mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "ALTER USER ${rootUserName} IDENTIFIED WITH mysql_native_password BY '${databaseRootPassword}';"
done

echo "Flushing privileges"
mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "FLUSH PRIVILEGES;"
