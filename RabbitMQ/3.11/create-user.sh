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
  --help                 Show this message
  --rabbitMqUser         RabbitMQ user
  --rabbitMqPassword     RabbitMQ password
  --rabbitMqVirtualHost  RabbitMQ virtual host, default: /

Example: ${scriptFileName} --rabbitMqUser newuser --rabbitMqPassword password --rabbitMqVirtualHost /
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

rabbitMqUser=
rabbitMqPassword=
rabbitMqVirtualHost=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${rabbitMqUser}" ]]; then
  echo "No RabbitMQ user specified!"
  usage
  exit 1
fi

if [[ -z "${rabbitMqPassword}" ]]; then
  echo "No RabbitMQ password specified!"
  usage
  exit 1
fi

if [[ -z "${rabbitMqVirtualHost}" ]]; then
  rabbitMqVirtualHost="/"
fi

if [[ -n "${rabbitMqUser}" ]] && [[ $(rabbitmqctl list_users 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -P "^${rabbitMqUser}$" | wc -l) -eq 0 ]]; then
  echo "Adding user: ${rabbitMqUser}"
  rabbitmqctl add_user "${rabbitMqUser}" "${rabbitMqPassword}"
  rabbitmqctl set_user_tags "${rabbitMqUser}" management
else
  echo "User: ${rabbitMqUser} already exists"
fi

if [[ -n "${rabbitMqVirtualHost}" ]] && [[ $(rabbitmqctl list_vhosts 2>/dev/null | tail -n +3 | awk '{print $1}' | grep "${rabbitMqVirtualHost}" | wc -l) -eq 0 ]]; then
  echo "Adding virtual host: ${rabbitMqVirtualHost}"
  rabbitmqctl add_vhost "${rabbitMqVirtualHost}"
else
  echo "Virtual host: ${rabbitMqVirtualHost} already exists"
fi

if [[ -n "${rabbitMqUser}" ]] && [[ -n "${rabbitMqVirtualHost}" ]] && [[ $(rabbitmqctl list_user_permissions "${rabbitMqUser}" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -P "^${rabbitMqVirtualHost}$" | wc -l) -eq 0 ]]; then
  echo "Adding permission for user: ${rabbitMqUser} to virtual host: ${rabbitMqVirtualHost}"
  rabbitmqctl set_permissions -p "${rabbitMqVirtualHost}" "${rabbitMqUser}" ".*" ".*" ".*"
else
  echo "User: ${rabbitMqUser} already has permission to virtual host: ${rabbitMqVirtualHost}"
fi
