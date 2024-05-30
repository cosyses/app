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

echo "[{rabbit, [{loopback_users, []}, {tcp_listeners, [${port}]}]}, {rabbitmq_management, [{listener, [{port, ${managementPort}}]}]}]." > /etc/rabbitmq/rabbitmq.config

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
#!/bin/bash -e
sudo -H -u rabbitmq bash -c "/usr/lib/rabbitmq/bin/rabbitmq-server"
EOF
  chmod +x /usr/local/bin/rabbitmq.sh
fi
