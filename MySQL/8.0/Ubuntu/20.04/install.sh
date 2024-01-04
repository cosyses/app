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
install-package-from-deb mysql-common 8.0.33-1ubuntu0.20.04 https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-common_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-community-client-plugins 8.0.33-1ubuntu0.20.04 https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client-plugins_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-community-client-core 8.0.33-1ubuntu0.20.04 https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client-core_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-community-client 8.0.33-1ubuntu0.20.04 https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-client_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-client 8.0.33-1ubuntu0.20.04  https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-client_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-community-server-core 8.0.33-1ubuntu0.20.04 https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-server-core_8.0.33-1ubuntu20.04_amd64.deb
install-package-from-deb mysql-community-server 8.0.33-1ubuntu0.20.04  https://repo.mysql.com/apt/ubuntu/pool/mysql-8.0/m/mysql-community/mysql-community-server_8.0.33-1ubuntu20.04_amd64.deb

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
  kill "$(cat /var/run/mysqld/mysqld.pid)"

  echo "Creating start script at: /usr/local/bin/mysql.sh"
  cat <<EOF > /usr/local/bin/mysql.sh
#!/bin/bash -e
/usr/sbin/mysqld --user mysql --pid-file=/var/run/mysqld/mysqld.pid
EOF
  chmod +x /usr/local/bin/mysql.sh
else
  echo "Restarting MySQL"
  service mysql restart
fi
