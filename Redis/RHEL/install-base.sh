#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Builds Redis from the source release, like the routine of Ubuntu.

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

# Set by the version specific install.sh which sources this script
if [[ -z "${redisVersion}" ]]; then
  >&2 echo "No Redis version specified!"
  echo ""
  exit 1
fi

install-package gcc
install-package make
install-package pkgconf-pkg-config

if [[ ! -d "/usr/local/source/redis/redis-${redisVersion}" ]]; then
  mkdir -p /usr/local/source/redis
  cd /usr/local/source/redis
  wget -nv "http://download.redis.io/releases/redis-${redisVersion}.tar.gz"
  tar xzf "redis-${redisVersion}.tar.gz"
  cd "redis-${redisVersion}"
  # One compile job per CPU can take more memory than available, so allow one job per 2 GB of available memory
  buildJobs=$(nproc)
  memoryJobs=$(awk '/^MemAvailable:/ {jobs = int($2 / 2097152); print (jobs < 1) ? 1 : jobs}' /proc/meminfo)
  if [[ -n "${memoryJobs}" ]] && [[ "${memoryJobs}" -lt "${buildJobs}" ]]; then
    buildJobs="${memoryJobs}"
  fi
  echo "Building with ${buildJobs} jobs"
  make -j"${buildJobs}"
  make install
else
  cd "/usr/local/source/redis/redis-${redisVersion}"
fi

configurationFile="/etc/redis/redis_${port}.conf"
pidFile="/var/run/redis_${port}.pid"

mkdir -p /etc/redis
mkdir -p /var/log/redis
mkdir -p "/var/lib/redis/${port}"

# The values utils/install_server.sh of Ubuntu's routine sets (it needs an init system of SysV, which RHEL lacks)
echo "Creating configuration at: ${configurationFile}"
sed \
  -e "s/^port .*/port ${port}/" \
  -e "s/^daemonize no/daemonize yes/" \
  -e "s#^pidfile .*#pidfile ${pidFile}#" \
  -e "s#^logfile .*#logfile /var/log/redis/${port}.log#" \
  -e "s#^dir .*#dir /var/lib/redis/${port}#" \
  redis.conf > "${configurationFile}"

echo "Setting bind address to: ${bindAddress}"
replace-file-content "${configurationFile}" "bind ${bindAddress}" "bind 127.0.0.1" 0

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
  echo "Creating service at: /etc/systemd/system/redis_${port}.service"
  cat <<EOF > "/etc/systemd/system/redis_${port}.service"
[Unit]
Description=Redis on port ${port}
After=network.target
[Service]
Type=forking
PIDFile=${pidFile}
ExecStart=/usr/local/bin/redis-server ${configurationFile}
ExecStop=/usr/local/bin/redis-cli -p ${port} shutdown
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "redis_${port}"
  echo "Restarting Redis"
  systemctl restart "redis_${port}"
fi
