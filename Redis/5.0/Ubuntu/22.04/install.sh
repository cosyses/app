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

redisVersion="5.0.14"

if [[ ! -d /usr/local/source/redis/redis-${redisVersion} ]]; then
  mkdir -p /usr/local/source/redis
  cd /usr/local/source/redis
  wget -nv http://download.redis.io/releases/redis-${redisVersion}.tar.gz
  tar xzf redis-${redisVersion}.tar.gz
  cd redis-${redisVersion}
  make
  make install
else
  cd /usr/local/source/redis/redis-${redisVersion}
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

if [[ -f /.dockerenv ]]; then
  echo "Stopping Redis"
  "/etc/init.d/redis_${port}" stop

  echo "Creating start script at: /usr/local/bin/redis.sh"
  cat <<EOF > /usr/local/bin/redis.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Redis"
  cat /var/run/redis_${port}.pid | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Redis"
/usr/local/bin/redis-server /etc/redis/redis_${port}.conf --daemonize yes &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/redis.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-redis.sh"
    cat <<EOF > /usr/local/lib/start/10-redis.sh
#!/usr/bin/env bash
echo "Starting Redis"
/usr/local/bin/redis-server /etc/redis/redis_${port}.conf --daemonize yes
EOF
    chmod +x /usr/local/lib/start/10-redis.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-redis.sh"
    cat <<EOF > /usr/local/lib/stop/10-redis.sh
#!/usr/bin/env bash
echo "Stopping Redis"
cat /var/run/redis_${port}.pid | xargs kill -15 && until test ! -f /var/run/redis_${port}.pid; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-redis.sh
  fi
else
  echo "Restarting Redis"
  service "redis_${port}" restart
fi
