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

# Set by the version specific install.sh which sources this script
if [[ -z "${valkeyVersion}" ]]; then
  >&2 echo "No Valkey version specified!"
  echo ""
  exit 1
fi

# Valkey 7.2 still has the install_server.sh of Redis with REDIS_* variables and redis_<port> names
if [[ "${valkeyVersion%%.*}" -lt 8 ]]; then
  variablePrefix="REDIS"
else
  variablePrefix="SERVER"
fi

install-package build-essential
install-package pkg-config

if [[ ! -d "/usr/local/source/valkey/valkey-${valkeyVersion}" ]]; then
  mkdir -p /usr/local/source/valkey
  cd /usr/local/source/valkey/
  wget -nv "https://github.com/valkey-io/valkey/archive/refs/tags/${valkeyVersion}.tar.gz"
  tar xfz "${valkeyVersion}.tar.gz"
  rm "${valkeyVersion}.tar.gz"
  cd "valkey-${valkeyVersion}/"
  make
  make install
  # Do not bail out on hosts managed by systemd
  sed -i '76,84s/^/#/' utils/install_server.sh
  if [[ "${variablePrefix}" == "REDIS" ]]; then
    # Use the same names for init script and pid file as Valkey 8
    sed -i -e 's/redis_\${REDIS_PORT}/valkey_${REDIS_PORT}/g' -e 's/redis_\$REDIS_PORT/valkey_$REDIS_PORT/g' -e 's/command -v redis-cli/command -v valkey-cli/' -e 's#/redis-cli"#/valkey-cli"#' utils/install_server.sh
  fi
else
  cd "/usr/local/source/valkey/valkey-${valkeyVersion}"
fi

cd utils
mkdir -p /etc/valkey/
mkdir -p /var/log/valkey
mkdir -p /var/lib/valkey
env \
  "${variablePrefix}_PORT=${port}" \
  "${variablePrefix}_CONFIG_FILE=/etc/valkey/valkey_${port}.conf" \
  "${variablePrefix}_LOG_FILE=/var/log/valkey/${port}.log" \
  "${variablePrefix}_DATA_DIR=/var/lib/valkey/${port}" \
  "${variablePrefix}_EXECUTABLE=$(command -v valkey-server)" \
  ./install_server.sh

add-file-content-before /etc/security/limits.conf "root  soft  nofile  10240" "# End of file" 1
add-file-content-before /etc/security/limits.conf "root  hard  nofile  1048576" "# End of file" 1
sysctl -p

echo "Setting bind address to: ${bindAddress}"
replace-file-content "/etc/valkey/valkey_${port}.conf" "bind ${bindAddress}" "bind 127.0.0.1" 0

if [[ -f /.dockerenv ]]; then
  echo "Disabling protected mode"
  replace-file-content "/etc/valkey/valkey_${port}.conf" "protected-mode no" "protected-mode yes" 0

  echo "Stopping Valkey"
  "/etc/init.d/valkey_${port}" stop

  echo "Creating start script at: /usr/local/bin/valkey.sh"
  cat <<EOF > /usr/local/bin/valkey.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Valkey"
  cat /var/run/valkey_${port}.pid | xargs kill -15 && until test ! -f /var/run/valkey_${port}.pid; do sleep 1; done
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Valkey"
/usr/local/bin/valkey-server /etc/valkey/valkey_${port}.conf &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/valkey.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-valkey.sh"
    cat <<EOF > /usr/local/lib/start/10-valkey.sh
#!/usr/bin/env bash
echo "Starting Valkey"
/usr/local/bin/valkey-server /etc/valkey/valkey_${port}.conf
EOF
    chmod +x /usr/local/lib/start/10-valkey.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-valkey.sh"
    cat <<EOF > /usr/local/lib/stop/10-valkey.sh
#!/usr/bin/env bash
echo "Stopping Valkey"
cat /var/run/valkey_${port}.pid | xargs kill -15 && until test ! -f /var/run/valkey_${port}.pid; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/10-valkey.sh
  fi
else
  echo "Restarting Valkey"
  service "valkey_${port}" restart
fi
