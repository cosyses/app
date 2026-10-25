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

export DEBIAN_FRONTEND=noninteractive

echo "Downloading libraries"
install-package perl
install-package libaio1
install-package libnuma1
install-package libmecab2
install-package libtinfo5
install-package psmisc

# Set by the release specific install.sh which sources this script
if [[ -z "${mysqlPackageVersion}" ]]; then
  >&2 echo "No MySQL package version specified!"
  echo ""
  exit 1
fi

release=$(lsb_release -r | awk '{print $2}' | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")
install-package-from-deb mysql-common ${mysqlPackageVersion}-1ubuntu0.${release} https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-common_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-community-client-plugins ${mysqlPackageVersion}-1ubuntu0.${release} https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client-plugins_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-community-client-core ${mysqlPackageVersion}-1ubuntu0.${release} https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client-core_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-community-client ${mysqlPackageVersion}-1ubuntu0.${release} https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-client ${mysqlPackageVersion}-1ubuntu0.${release}  https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-client_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-community-server-core ${mysqlPackageVersion}-1ubuntu0.${release} https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-server-core_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb
install-package-from-deb mysql-community-server ${mysqlPackageVersion}-1ubuntu0.${release}  https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-server_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb

if [[ -f /.dockerenv ]]; then
  echo "Starting MySQL"
  /usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
fi

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
sed -i "s/bind-address.*/bind-address = ${bindAddress}/g" /etc/mysql/mysql.conf.d/mysqld.cnf

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
  export MYSQL_PWD="${databaseRootPassword}"
  mysqladmin shutdown
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting MySQL"
/usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/mysql.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-mysql.sh"
    cat <<EOF > /usr/local/lib/start/10-mysql.sh
#!/usr/bin/env bash
echo "Starting MySQL"
/usr/sbin/mysqld --daemonize --user mysql --pid-file=/var/run/mysqld/mysqld.pid
EOF
    chmod +x /usr/local/lib/start/10-mysql.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-mysql.sh"
    cat <<EOF > /usr/local/lib/stop/10-mysql.sh
#!/usr/bin/env bash
echo "Stopping MySQL"
export MYSQL_PWD="${databaseRootPassword}"
mysqladmin shutdown
EOF
    chmod +x /usr/local/lib/stop/10-mysql.sh
  fi
else
  echo "Restarting MySQL"
  service mysql restart
fi
