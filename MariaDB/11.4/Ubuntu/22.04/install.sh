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
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-11.4" --os-type="ubuntu" --os-version="jammy"

export DEBIAN_FRONTEND=noninteractive

echo "Downloading libraries"
install-package mariadb-server 1:11.4

echo "Setting port to: ${databaseRootPort}"
replace-file-content /etc/mysql/mariadb.cnf "port = ${databaseRootPort}" "# port = 3306" 0

echo "Disabling SSL certificate validation"
replace-file-content /etc/mysql/mariadb.conf.d/50-client.cnf "ssl-verify-server-cert = off" "#ssl-verify-server-cert = on" 1

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
sleep 3
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
echo "Starting MariaDB"
/usr/sbin/mysqld \
  --basedir=/usr \
  --datadir=/var/lib/mysql \
  --plugin-dir=/usr/lib/mysql/plugin \
  --user=mysql \
  --skip-log-error \
  --pid-file=/var/run/mysqld/mysqld.pid \
  --socket=/var/run/mysqld/mysqld.sock &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/mariadb.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-mariadb.sh"
    cat <<EOF > /usr/local/lib/start/10-mariadb.sh
#!/usr/bin/env bash
/usr/bin/install \
  -m 755 \
  -o mysql \
  -g root \
  -d /var/run/mysqld
echo "Starting MariaDB"
/usr/sbin/mysqld \
  --basedir=/usr \
  --datadir=/var/lib/mysql \
  --plugin-dir=/usr/lib/mysql/plugin \
  --user=mysql \
  --skip-log-error \
  --pid-file=/var/run/mysqld/mysqld.pid \
  --socket=/var/run/mysqld/mysqld.sock &
EOF
    chmod +x /usr/local/lib/start/10-mariadb.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-mariadb.sh"
    cat <<EOF > /usr/local/lib/stop/10-mariadb.sh
#!/usr/bin/env bash
echo "Stopping MariaDB"
mariadb-admin shutdown
EOF
    chmod +x /usr/local/lib/stop/10-mariadb.sh
  fi
else
  echo "Starting MariaDB"
  /etc/init.d/mariadb start
fi
