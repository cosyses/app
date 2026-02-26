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

# install prerequisites
install-package libaio1
install-package libjemalloc2
install-package gawk
install-package iproute2
install-package libdbi-perl
install-package lsof
install-package psmisc
install-package rsync
install-package socat
install-package galera-3
install-package libconfig-inifiles-perl
install-package libsnappy1v5
install-package-from-deb libreadline5 5.2 http://launchpadlibrarian.net/440386672/libreadline5_5.2+dfsg-3build3_amd64.deb

export DEBIAN_FRONTEND=noninteractive

# install MariaDB
install-package mysql-common
install-package-from-deb mariadb-common 10.3 http://launchpadlibrarian.net/710729642/mariadb-common_10.3.39-0ubuntu0.20.04.2_all.deb
install-package-from-deb mariadb-server-core-10.3 10.3 http://launchpadlibrarian.net/710729682/mariadb-server-core-10.3_10.3.39-0ubuntu0.20.04.2_amd64.deb
install-package-from-deb mariadb-client-core-10.3 10.3 http://launchpadlibrarian.net/710729670/mariadb-client-core-10.3_10.3.39-0ubuntu0.20.04.2_amd64.deb
install-package-from-deb mariadb-client-10.3 10.3 http://launchpadlibrarian.net/710729669/mariadb-client-10.3_10.3.39-0ubuntu0.20.04.2_amd64.deb
install-package-from-deb mariadb-server-10.3 10.3 http://launchpadlibrarian.net/710729681/mariadb-server-10.3_10.3.39-0ubuntu0.20.04.2_amd64.deb
install-package-from-deb mariadb-server 10.3 http://launchpadlibrarian.net/710729662/mariadb-server_10.3.39-0ubuntu0.20.04.2_all.deb

echo "Setting port to: ${databaseRootPort}"
replace-file-content /etc/mysql/mariadb.conf.d/50-server.cnf "port                    = ${databaseRootPort}" "#port                   = 3306" 0

echo "Starting MariaDB"
/etc/init.d/mysql start

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

sleep 3
echo "Stopping MariaDB"
cat /var/run/mysqld/mysqld.pid | xargs kill -15 && until test ! -f /var/run/mysqld/mysqld.pid; do sleep 1; done

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/mariadb.sh"
  cat <<EOF > /usr/local/bin/mariadb.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MariaDB"
  cat /var/run/mysqld/mysqld.pid | xargs kill -15 && until test ! -f /var/run/mysqld/mysqld.pid; do sleep 1; done
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
cat /var/run/mysqld/mysqld.pid | xargs kill -15 && until test ! -f /var/run/mysqld/mysqld.pid; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-mariadb.sh
  fi
else
  echo "Starting MariaDB"
  /etc/init.d/mariadb start
fi
