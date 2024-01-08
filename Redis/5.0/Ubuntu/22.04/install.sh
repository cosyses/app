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
  --help         Show this message
  --bindAddress  Bind address, default: 127.0.0.1
  --port         Port, default: 6379

Example: ${scriptFileName} --bindAddress 0.0.0.0
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  bindAddress="127.0.0.1"
fi

if [[ -z "${port}" ]]; then
  port="6379"
fi

install-package build-essential
install-package pkg-config
install-package tcl
install-package tk

if [[ ! -d /usr/local/source/redis/redis-5.0.14 ]]; then
  mkdir -p /usr/local/source/redis
  cd /usr/local/source/redis
  wget -nv http://download.redis.io/releases/redis-5.0.14.tar.gz
  tar xzf redis-5.0.14.tar.gz
  cd redis-5.0.14
  make
  make install
else
  cd /usr/local/source/redis/redis-5.0.14
fi

cd utils
mkdir -p /etc/redis/
mkdir -p /var/log/redis
mkdir -p /var/lib/redis
REDIS_PORT=${port} \
REDIS_CONFIG_FILE=/etc/redis/redis_${port}.conf \
REDIS_LOG_FILE=/var/log/redis/${port}.log \
REDIS_DATA_DIR=/var/lib/redis/${port} \
REDIS_EXECUTABLE=$(command -v redis-server) \
./install_server.sh

add-file-content-before /etc/security/limits.conf "root  soft  nofile  10240" "# End of file" 1
add-file-content-before /etc/security/limits.conf "root  hard  nofile  1048576" "# End of file" 1
sysctl -p

echo "Setting bind address to: ${bindAddress}"
replace-file-content "/etc/redis/redis_${port}.conf" "bind ${bindAddress}" "bind 127.0.0.1" 0

echo "Disabling protected mode"
replace-file-content "/etc/redis/redis_${port}.conf" "protected-mode no" "protected-mode yes" 0

if [[ -f /.dockerenv ]]; then
  echo "Stopping Redis"
  "/etc/init.d/redis_${port}" stop

  echo "Creating start script at: /usr/local/bin/redis.sh"
  cat <<EOF > /usr/local/bin/redis.sh
#!/bin/bash -e
/usr/local/bin/redis-server /etc/redis/redis_${port}.conf --daemonize no
EOF
  chmod +x /usr/local/bin/redis.sh
else
  echo "Restarting Redis"
  service "redis_${port}" restart
fi
