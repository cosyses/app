#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                     Show this message
  --databaseRootHost         Server host name, default: localhost
  --databaseRootPort         Server port, default: 3306
  --databaseRootPassword     Current root password
  --newDatabaseRootPassword  New root password

Changes the password of every root user ('root'@'<host>'). The unix_socket authentication of 'root'@'localhost'
(MariaDB 10.4 and later) is kept.

Example: ${scriptName} --databaseRootPassword old_secret --newDatabaseRootPassword new_secret
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
newDatabaseRootPassword=
source "${cosysesPath}/prepare-parameters.sh"

# A value for a string in SQL: backslashes and single quotes escaped
sqlString()
{
  local value="${1//\\/\\\\}"
  echo "${value//\'/\'\'}"
}

if [[ -z "${databaseRootHost}" ]]; then
  databaseRootHost="localhost"
fi

if [[ -z "${databaseRootPort}" ]]; then
  databaseRootPort="3306"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  >&2 echo "No database root password specified!"
  usage
  exit 1
fi

if [[ -z "${newDatabaseRootPassword}" ]]; then
  >&2 echo "No new database root password specified!"
  usage
  exit 1
fi

export MYSQL_PWD="${databaseRootPassword}"

mapfile -t rootHosts < <(mariadb -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -N -B -e "SELECT Host FROM mysql.user WHERE User = 'root';")

if [[ "${#rootHosts[@]}" -eq 0 ]]; then
  >&2 echo "No root users found!"
  exit 1
fi

update=
for rootHost in "${rootHosts[@]}"; do
  echo "Changing password of user: 'root'@'${rootHost}'"
  # SET PASSWORD fails for 'root'@'localhost', which authenticates via unix_socket or the password since MariaDB 10.4
  if mariadb -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -N -B -e "SHOW CREATE USER 'root'@'${rootHost}';" | grep -q "unix_socket"; then
    update="${update} ALTER USER 'root'@'${rootHost}' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('$(sqlString "${newDatabaseRootPassword}")');"
  else
    update="${update} ALTER USER 'root'@'${rootHost}' IDENTIFIED BY '$(sqlString "${newDatabaseRootPassword}")';"
  fi
done
update="${update} FLUSH PRIVILEGES;"

mariadb -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "${update}"

export MYSQL_PWD="${newDatabaseRootPassword}"

# on localhost, the client would use the socket and possibly unix_socket authentication without checking the password
checkHost="${databaseRootHost}"
if [[ "${checkHost}" == "localhost" ]]; then
  checkHost="127.0.0.1"
fi

echo "Checking new password"
mariadb -h"${checkHost}" -P"${databaseRootPort}" -u root -e "SELECT 1;" > /dev/null
