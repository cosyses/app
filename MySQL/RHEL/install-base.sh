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
  --databaseRootPassword  User password, default: <generated>
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

# Set by the version specific install.sh which sources this script: the version prefix of the packages, their names
# and the repository of the MySQL project (as path below https://repo.mysql.com/yum/, empty for the packages of the
# distribution)
if [[ -z "${mysqlVersion}" ]] || [[ -z "${mysqlServerPackage}" ]] || [[ -z "${mysqlClientPackage}" ]]; then
  >&2 echo "No MySQL version or packages specified!"
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

if [[ -n "${mysqlRepository}" ]]; then
  # The priority hides the MySQL packages of the distribution, module_hotfixes the module streams of RHEL
  add-dnf-repository mysql-community "https://repo.mysql.com/yum/${mysqlRepository}/\$basearch/" "https://repo.mysql.com/RPM-GPG-KEY-mysql-2025 https://repo.mysql.com/RPM-GPG-KEY-mysql-2023" module_hotfixes=1 priority=10
fi

install-package psmisc
install-package "${mysqlClientPackage}" "${mysqlVersion}"
install-package "${mysqlServerPackage}" "${mysqlVersion}"

# The packages of the MySQL project install the server as /usr/sbin/mysqld, Fedora's as /usr/libexec/mysqld
mysqldBinary=$(command -v mysqld || true)
if [[ -z "${mysqldBinary}" ]]; then
  mysqldBinary="/usr/libexec/mysqld"
fi

# Fedora's server has file capabilities, which a container without these capabilities refuses to run
if [[ -f /.dockerenv ]]; then
  install-package libcap
  if [[ -n "$(getcap "$(readlink -f "${mysqldBinary}")")" ]]; then
    echo "Removing file capabilities of: $(readlink -f "${mysqldBinary}")"
    setcap -r "$(readlink -f "${mysqldBinary}")"
  fi
fi

echo "Allowing binding from: ${bindAddress}"
# The my.cnf of the MySQL project does not include the directory /etc/my.cnf.d, the one of Fedora does
mkdir -p /etc/my.cnf.d
if ! grep -q '^!includedir /etc/my.cnf.d' /etc/my.cnf; then
  echo "!includedir /etc/my.cnf.d" >> /etc/my.cnf
fi
cat <<EOF > /etc/my.cnf.d/zz-cosyses.cnf
[mysqld]
bind-address = ${bindAddress}
port = ${databaseRootPort}
pid-file = /var/run/mysqld/mysqld.pid
EOF

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# The service of systemd initializes the data directory with a temporary password, the root user gets its password
# from root-user.sh, so it starts without one
if [[ ! -d /var/lib/mysql/mysql ]]; then
  echo "Initializing data directory"
  "${mysqldBinary}" --initialize-insecure --user=mysql
fi

if [[ -f /.dockerenv ]]; then
  echo "Starting MySQL"
  "${mysqldBinary}" --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
else
  echo "Starting MySQL"
  systemctl enable mysqld
  systemctl restart mysqld
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "root-user.sh" \
  --databaseRootPassword "${databaseRootPassword}"

if [[ -f /.dockerenv ]]; then
  echo "Stopping MySQL"
  export MYSQL_PWD="${databaseRootPassword}"
  mysqladmin shutdown

  echo "Creating start script at: /usr/local/bin/mysql.sh"
  cat <<EOF > /usr/local/bin/mysql.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MySQL"
  export MYSQL_PWD=$(printf '%q' "${databaseRootPassword}")
  mysqladmin shutdown
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting MySQL"
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
${mysqldBinary} --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/mysql.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-mysql.sh"
    cat <<EOF > /usr/local/lib/start/10-mysql.sh
#!/usr/bin/env bash
echo "Starting MySQL"
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
${mysqldBinary} --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
EOF
    chmod +x /usr/local/lib/start/10-mysql.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-mysql.sh"
    cat <<EOF > /usr/local/lib/stop/10-mysql.sh
#!/usr/bin/env bash
echo "Stopping MySQL"
export MYSQL_PWD=$(printf '%q' "${databaseRootPassword}")
mysqladmin shutdown
EOF
    chmod +x /usr/local/lib/stop/10-mysql.sh
  fi
fi
