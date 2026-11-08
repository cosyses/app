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

# The MySQL repository keeps the packages of all previous versions, so this version stays installable (amd64 only)
mysqlPackageVersion="8.4.13"
release=$(lsb_release -r | awk '{print $2}' | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")
packageUrl="https://repo.mysql.com/apt/ubuntu/pool/mysql-8.4-lts/m/mysql-community"
packageNames=( mysql-common mysql-community-client-plugins mysql-community-client-core mysql-community-client mysql-client mysql-community-server-core mysql-community-server )

if [[ "$(get-installed-package-version mysql-community-server)" == "${mysqlPackageVersion}-1ubuntu${release}" ]]; then
  echo "MySQL ${mysqlPackageVersion} already installed"
else
  install-package wget
  install-package psmisc
  downloadPath=$(mktemp -d)
  packageFiles=()
  for packageName in "${packageNames[@]}"; do
    packageFile="${downloadPath}/${packageName}_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb"
    echo "Downloading package: ${packageName} ${mysqlPackageVersion}"
    wget -nv -O "${packageFile}" "${packageUrl}/${packageName}_${mysqlPackageVersion}-1ubuntu${release}_amd64.deb"
    packageFiles+=( "${packageFile}" )
  done
  echo "Installing MySQL ${mysqlPackageVersion}"
  UCF_FORCE_CONFOLD=1 apt-get install -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y "${packageFiles[@]}" 2>&1
  rm -rf "${downloadPath}"
fi

if [[ -f /.dockerenv ]]; then
  echo "Starting MySQL"
  mkdir -p /var/run/mysqld
  chown mysql:mysql /var/run/mysqld
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
if [[ -f /etc/sysctl.conf ]]; then
  sysctl -p
fi

echo "Allowing binding from: ${bindAddress}"
if grep -q "^bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf; then
  sed -i "s/^bind-address.*/bind-address = ${bindAddress}/g" /etc/mysql/mysql.conf.d/mysqld.cnf
else
  echo "bind-address = ${bindAddress}" >> /etc/mysql/mysql.conf.d/mysqld.cnf
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
  export MYSQL_PWD="${databaseRootPassword}"
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
export MYSQL_PWD="${databaseRootPassword}"
mysqladmin shutdown
EOF
    chmod +x /usr/local/lib/stop/10-mysql.sh
  fi
else
  echo "Restarting MySQL"
  service mysql restart
fi
