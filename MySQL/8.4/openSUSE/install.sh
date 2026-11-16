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

# The MySQL repository keeps the packages of all previous versions, so this version stays installable. It has packages
# for SUSE Linux Enterprise 15 only, which Leap 15.6 is based on and which also work on Leap 16.0.
mysqlPackageVersion="8.4.13"
# RPM-GPG-KEY-mysql-2025 is the key of 2023 with the expiry extended to 2027, which the rpm of Leap 16.0 requires
add-zypper-repository mysql-8.4-community "https://repo.mysql.com/yum/mysql-8.4-community/suse/15/$(uname -m)/" "https://repo.mysql.com/RPM-GPG-KEY-mysql-2025"

install-package mysql-community-client "${mysqlPackageVersion}"
install-package mysql-community-server "${mysqlPackageVersion}"
install-package psmisc

# The packages initialize the data directory in the start script of systemd only
if [[ ! -d /var/lib/mysql/mysql ]]; then
  echo "Initializing data directory"
  mkdir -p /var/lib/mysql
  chown mysql:mysql /var/lib/mysql
  /usr/sbin/mysqld --initialize-insecure --user=mysql
fi

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

if [[ -f /.dockerenv ]]; then
  echo "Starting MySQL"
  /usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
else
  echo "Starting MySQL"
  systemctl enable mysql
  systemctl restart mysql
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript "root-user.sh" \
  --databaseRootPassword "${databaseRootPassword}"

# Leap 16.0 has no /etc/security/limits.conf, both read the files in limits.d
echo "Increasing file limits at: /etc/security/limits.d/mysql.conf"
mkdir -p /etc/security/limits.d
printf 'mysql  soft  nofile  65535\nmysql  hard  nofile  65535\n' > /etc/security/limits.d/mysql.conf

echo "Allowing binding from: ${bindAddress}"
if grep -q "^bind-address" /etc/my.cnf; then
  sed -i "s/^bind-address.*/bind-address = ${bindAddress}/g" /etc/my.cnf
else
  sed -i "/^\[mysqld\]/a bind-address = ${bindAddress}" /etc/my.cnf
fi

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
/usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
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
/usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
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
else
  echo "Restarting MySQL"
  systemctl restart mysql
fi
