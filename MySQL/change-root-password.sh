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

Changes the password of every root user ('root'@'<host>') and keeps their authentication plugin.
Container start and stop scripts which contain the current password are updated.

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

mapfile -t rootHosts < <(mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -N -B -e "SELECT Host FROM mysql.user WHERE User = 'root';")

if [[ "${#rootHosts[@]}" -eq 0 ]]; then
  >&2 echo "No root users found!"
  exit 1
fi

update=
for rootHost in "${rootHosts[@]}"; do
  echo "Changing password of user: 'root'@'${rootHost}'"
  update="${update} ALTER USER 'root'@'${rootHost}' IDENTIFIED BY '${newDatabaseRootPassword}';"
done
update="${update} FLUSH PRIVILEGES;"

mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "${update}"

export MYSQL_PWD="${newDatabaseRootPassword}"

echo "Checking new password"
mysql -h"${databaseRootHost}" -P"${databaseRootPort}" -u root -e "SELECT 1;" > /dev/null

currentPasswordLine="export MYSQL_PWD=\"${databaseRootPassword}\""
newPasswordLine="export MYSQL_PWD=\"${newDatabaseRootPassword}\""
scriptFiles=( /usr/local/bin/mysql.sh /usr/local/lib/stop/10-mysql.sh )
for scriptFile in "${scriptFiles[@]}"; do
  if [[ -f "${scriptFile}" ]] && grep -qF "${currentPasswordLine}" "${scriptFile}"; then
    echo "Updating password in script: ${scriptFile}"
    scriptLines=()
    while IFS= read -r scriptLine || [[ -n "${scriptLine}" ]]; do
      if [[ "${scriptLine}" == *"${currentPasswordLine}" ]]; then
        scriptLine="${scriptLine%"${currentPasswordLine}"}${newPasswordLine}"
      fi
      scriptLines+=( "${scriptLine}" )
    done < "${scriptFile}"
    printf '%s\n' "${scriptLines[@]}" > "${scriptFile}"
  fi
done
