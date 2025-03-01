#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help                  Show this message
  --databaseRootHost      Server host name, default: localhost
  --databaseRootPort      Server port, default: 3306
  --databaseRootPassword  Root password, default: <generated>
  --bindAddress           Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment

Example: ${scriptFileName} --databaseRootPassword secret
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

databaseRootHost=
databaseRootPort=
databaseRootPassword=
bindAddress=
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

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

echo "Setting up installation"
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.6" --os-type="ubuntu" --os-version="jammy"

export DEBIAN_FRONTEND=noninteractive

echo "Downloading libraries"
install-package mariadb-server 1:10.6

echo "Fix start script"
# shellcheck disable=SC2016
replace-file-content /etc/init.d/mariadb '[ -z "$datadir" ]' '[ -z "$datadir"]' 0

echo "Setting port to: ${databaseRootPort}"
add-file-content-after /etc/mysql/mariadb.conf.d/50-server.cnf "port = ${databaseRootPort}" "[mysqld]" 1

echo "Starting MariaDB"
/etc/init.d/mariadb start

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "root-user.sh" \
  --databaseRootPassword "${databaseRootPassword}"

echo "Increasing file limits"
add-file-content-before /etc/security/limits.conf "mysql  soft  nofile  65535" "# End of file" 1
add-file-content-before /etc/security/limits.conf "mysql  hard  nofile  65535" "# End of file" 1
sysctl -p

echo "Allowing binding from: ${bindAddress}"
replace-file-content /etc/mysql/mariadb.conf.d/50-server.cnf "bind-address            = ${bindAddress}" "bind-address            = 127.0.0.1"

echo "Adding skipping of DNS lookup"
replace-file-content /etc/mysql/mariadb.conf.d/50-server.cnf "skip-name-resolve" "#skip-name-resolve" 0

echo "Stopping MariaDB"
/etc/init.d/mariadb stop

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/mariadb.sh"
  cat <<EOF > /usr/local/bin/mariadb.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MariaDB"
  mariadb-admin shutdown
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
/usr/bin/install \
  -m 755 \
  -o mysql \
  -g root \
  -d /var/run/mysqld
rm -rf mariadb.out
echo "Starting MariaDB"
nohup /usr/sbin/mysqld \
  --basedir=/usr \
  --datadir=/var/lib/mysql \
  --plugin-dir=/usr/lib/mysql/plugin \
  --user=mysql \
  --skip-log-error \
  --pid-file=/var/run/mysqld/mysqld.pid \
  --socket=/var/run/mysqld/mysqld.sock > mariadb.out 2>&1 &
tail -f mariadb.out & wait \$!
EOF
  chmod +x /usr/local/bin/mariadb.sh
else
  echo "Starting MariaDB"
  /etc/init.d/mariadb start
fi
