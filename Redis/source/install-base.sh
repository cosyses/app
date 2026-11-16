#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Builds Redis from the source release and configures an instance like install_server.sh of Ubuntu does (configuration
in /etc/redis/redis_<port>.conf), without its init script, which needs the init system of Debian.

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

# Set by the version specific install.sh which sources this script, the full source release, e.g. 7.2.12
if [[ -z "${redisVersion}" ]]; then
  >&2 echo "No Redis version specified!"
  echo ""
  exit 1
fi

if [[ -x "$(command -v apk)" ]]; then
  install-package build-base
  install-package linux-headers
elif [[ -x "$(command -v zypper)" ]] || [[ -x "$(command -v dnf)" ]]; then
  install-package gcc
  install-package make
else
  install-package build-essential
  install-package pkg-config
fi
install-package tar
install-package gzip

if [[ "$(/usr/local/bin/redis-server --version 2>/dev/null | grep -oE 'v=[0-9.]+' | cut -c3-)" == "${redisVersion}" ]]; then
  echo "Redis ${redisVersion} already installed"
else
  mkdir -p /usr/local/source/redis
  cd /usr/local/source/redis
  if [[ ! -d "redis-${redisVersion}" ]]; then
    echo "Downloading Redis ${redisVersion}"
    wget -nv "https://download.redis.io/releases/redis-${redisVersion}.tar.gz"
    tar xzf "redis-${redisVersion}.tar.gz"
    rm -f "redis-${redisVersion}.tar.gz"
  fi
  cd "redis-${redisVersion}"
  echo "Building Redis ${redisVersion}"
  make
  make install
fi

configurationFile="/etc/redis/redis_${port}.conf"
pidFile="/var/run/redis_${port}.pid"

mkdir -p /etc/redis
mkdir -p /var/log/redis
mkdir -p "/var/lib/redis/${port}"

echo "Creating configuration at: ${configurationFile}"
sed \
  -e "s/^port .*/port ${port}/" \
  -e "s/^daemonize .*/daemonize yes/" \
  -e "s#^pidfile .*#pidfile ${pidFile}#" \
  -e "s#^logfile .*#logfile /var/log/redis/${port}.log#" \
  -e "s#^dir .*#dir /var/lib/redis/${port}#" \
  -e "s/^bind .*/bind ${bindAddress}/" \
  "/usr/local/source/redis/redis-${redisVersion}/redis.conf" > "${configurationFile}"
if ! grep -q "^bind " "${configurationFile}"; then
  echo "bind ${bindAddress}" >> "${configurationFile}"
fi

if [[ -f /.dockerenv ]]; then
  echo "Disabling protected mode"
  replace-file-content "${configurationFile}" "protected-mode no" "protected-mode yes" 0

  echo "Creating start script at: /usr/local/bin/redis.sh"
  cat <<EOF > /usr/local/bin/redis.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Redis"
  cat ${pidFile} | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Redis"
/usr/local/bin/redis-server ${configurationFile} --daemonize yes &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/redis.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-redis.sh"
    cat <<EOF > /usr/local/lib/start/10-redis.sh
#!/usr/bin/env bash
echo "Starting Redis"
/usr/local/bin/redis-server ${configurationFile} --daemonize yes
EOF
    chmod +x /usr/local/lib/start/10-redis.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-redis.sh"
    cat <<EOF > /usr/local/lib/stop/10-redis.sh
#!/usr/bin/env bash
echo "Stopping Redis"
cat ${pidFile} | xargs kill -15 && until test ! -f ${pidFile}; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-redis.sh
  fi
else
  if [[ -f "${pidFile}" ]]; then
    echo "Stopping Redis"
    xargs kill -15 < "${pidFile}" || true
    while [[ -f "${pidFile}" ]]; do sleep 1; done
  fi
  echo "Starting Redis"
  /usr/local/bin/redis-server "${configurationFile}" --daemonize yes
fi
