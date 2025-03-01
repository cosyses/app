#!/bin/bash -e

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

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

if [[ -z "${helpRequested}" ]]; then
  >&2 echo "No help requested exported!"
  echo ""
  exit 1
fi

usage()
{
cat >&2 << EOF

usage: cosyses ${applicationName} ${applicationVersion} [options]

OPTIONS:
  --help            Show this message
  --bindAddress     Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment
  --port            Server port, default: 5672
  --managementPort  Port of Management GUI, default: 15672
  --adminUserName   Name of admin user, default: admin
  --adminPassword   Password of admin user, default: <generated>

Example: cosyses ${applicationName} ${applicationVersion} --adminPassword secret

EOF
}

if [[ "${helpRequested}" == 1 ]]; then
  usage
  exit 1
fi

port=
managementPort=
adminUserName=
adminPassword=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

if [[ -z "${port}" ]]; then
  port=5672
fi

if [[ -z "${managementPort}" ]]; then
  managementPort=15672
fi

if [[ -z "${adminUserName}" ]]; then
  adminUserName="admin"
fi

add-server-key-id "hkps://keys.openpgp.org" "0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"
add-server-key-id "keyserver.ubuntu.com" "F77F1EDA57EBB1CC"

add-gpg-repository "erlang.list" "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/deb/ubuntu" "bionic" "main" "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key" "y"
add-gpg-repository "rabbitmq.list" "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/deb/ubuntu" "bionic" "main" "https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/gpg.9F4587F226208342.key" "y"

add-repository "focal-security.list" "http://security.ubuntu.com/ubuntu" "focal-security" "main"

## install prerequisites
install-package libssl1.1

## Install Erlang packages
install-package erlang-base 1:25.2.3
install-package erlang-crypto 1:25.2.3
install-package erlang-eldap 1:25.2.3
install-package erlang-inets 1:25.2.3
install-package erlang-os-mon 1:25.2.3
install-package erlang-parsetools 1:25.2.3
install-package erlang-public-key 1:25.2.3
install-package erlang-tools 1:25.2.3
install-package erlang-xmerl 1:25.2.3

## Install rabbitmq-server and its dependencies
install-package rabbitmq-server 3.11

rabbitmq-plugins enable rabbitmq_management

echo "Setting bind address to: ${bindAddress}, port to: ${port} and management port to: ${managementPort}"
echo "[{rabbit, [{loopback_users, []}, {tcp_listeners, [{\"${bindAddress}\", ${port}}]}]}, {rabbitmq_management, [{listener, [{ip, \"${bindAddress}\"}, {port, ${managementPort}}]}]}]." > /etc/rabbitmq/rabbitmq.config

service rabbitmq-server restart

if [[ -z "${adminPassword}" ]]; then
  adminPassword=$(echo "${RANDOM}" | md5sum | head -c 32)
  echo "Using generated password: ${adminPassword}"
fi

rabbitmqctl add_user "${adminUserName}" "${adminPassword}"
rabbitmqctl set_user_tags "${adminUserName}" administrator
rabbitmqctl set_permissions -p / "${adminUserName}" ".*" ".*" ".*"
rabbitmqctl delete_user guest

if [[ -f /.dockerenv ]]; then
  echo "Stopping RabbitMQ server"
  service rabbitmq-server stop

  echo "Creating start script at: /usr/local/bin/rabbitmq.sh"
  cat <<EOF > /usr/local/bin/rabbitmq.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping RabbitMQ"
  sudo -H -u rabbitmq bash -c "rabbitmqctl stop"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting RabbitMQ"
sudo -H -u rabbitmq bash -c "/usr/sbin/rabbitmq-server -detached" &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/rabbitmq.sh
fi
