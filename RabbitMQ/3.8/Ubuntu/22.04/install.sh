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
  --help            Show this message
  --port            Server port, default: 5672
  --managementPort  Port of Management GUI, default: 15672
  --adminUserName   Name of admin user, default: admin
  --adminPassword   Password of admin user, default: <generated>

Example: ${scriptFileName} --adminPassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

port=
managementPort=
adminUserName=
adminPassword=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${port}" ]]; then
  port=5672
fi

if [[ -z "${managementPort}" ]]; then
  managementPort=15672
fi

if [[ -z "${adminUserName}" ]]; then
  adminUserName="admin"
fi

if [[ -z "${adminPassword}" ]]; then
  adminPassword=$(echo "${RANDOM}" | md5sum | head -c 32)
  echo "Using generated password: ${adminPassword}"
fi

add-server-key-id "hkps://keys.openpgp.org" "0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"
add-server-key-id "keyserver.ubuntu.com" "F77F1EDA57EBB1CC"
add-gpg-repository "rabbitmq.list" "https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/" "focal" "main" "https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey" "y"

## Install Erlang packages
install-package erlang-base
install-package erlang-asn1
install-package erlang-eldap
install-package erlang-ftp
install-package erlang-inets
install-package erlang-os-mon
install-package erlang-parsetools
install-package erlang-tools
install-package erlang-xmerl

## Install rabbitmq-server and its dependencies
install-package rabbitmq-server 3.8

rabbitmq-plugins enable rabbitmq_management

echo "[{rabbit, [{loopback_users, []}, {tcp_listeners, [${port}]}]}, {rabbitmq_management, [{listener, [{port, ${managementPort}}]}]}]." > /etc/rabbitmq/rabbitmq.config

service rabbitmq-server restart

rabbitmqctl add_user "${adminUserName}" "${adminPassword}"
rabbitmqctl set_user_tags "${adminUserName}" administrator
rabbitmqctl set_permissions -p / "${adminUserName}" ".*" ".*" ".*"
rabbitmqctl delete_user guest

if [[ -f /.dockerenv ]]; then
  echo "Stopping RabbitMQ server"
  service rabbitmq-server stop

  echo "Creating start script at: /usr/local/bin/rabbitmq.sh"
  cat <<EOF > /usr/local/bin/rabbitmq.sh
#!/bin/bash -e
sudo -H -u rabbitmq bash -c "/usr/lib/rabbitmq/bin/rabbitmq-server"
EOF
  chmod +x /usr/local/bin/rabbitmq.sh
fi

mkdir -p /opt/install/
crudini --set /opt/install/env.properties rabbitmq version "3.8"
crudini --set /opt/install/env.properties rabbitmq port "${port}"
crudini --set /opt/install/env.properties rabbitmq management "${managementPort}"
crudini --set /opt/install/env.properties rabbitmq adminUser "${adminUserName}"
crudini --set /opt/install/env.properties rabbitmq adminPassword "${adminPassword}"