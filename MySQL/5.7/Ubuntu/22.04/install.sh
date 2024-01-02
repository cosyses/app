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
  --serverId              Server Id, default: 1

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
serverId=
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

if [[ -z "${serverId}" ]]; then
  serverId="1"
fi

export DEBIAN_FRONTEND=noninteractive

echo "Downloading libraries"
install-package perl
install-package psmisc
install-package libaio1
install-package libnuma1
install-package libmecab2
install-package libtinfo5
install-package-from-deb mysql-common 5.7.21-1ubuntu17.10 https://repo.mysql.com/apt/pool/mysql-5.7/m/mysql-community/mysql-common_5.7.21-1ubuntu17.10_amd64.deb
install-package-from-deb mysql-community-client 5.7.21-1ubuntu17.10 https://repo.mysql.com/apt/pool/mysql-5.7/m/mysql-community/mysql-community-client_5.7.21-1ubuntu17.10_amd64.deb
install-package-from-deb mysql-client 5.7.21-1ubuntu17.10 https://repo.mysql.com/apt/pool/mysql-5.7/m/mysql-community/mysql-client_5.7.21-1ubuntu17.10_amd64.deb
install-package-from-deb mysql-community-server 5.7.21-1ubuntu17.10 https://repo.mysql.com/apt/pool/mysql-5.7/m/mysql-community/mysql-community-server_5.7.21-1ubuntu17.10_amd64.deb
install-package-from-deb mysql-server 5.7.21-1ubuntu17.10 https://repo.mysql.com/apt/pool/mysql-5.7/m/mysql-community/mysql-server_5.7.21-1ubuntu17.10_amd64.deb

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
