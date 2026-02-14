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
  --help              Show this message
  --queueUser         RabbitMQ user
  --queuePassword     RabbitMQ password
  --queueVirtualHost  RabbitMQ virtual host, default: /

Example: ${scriptFileName} --queueUser newuser --queuePassword password --queueVirtualHost /
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

queueUser=
queuePassword=
queueVirtualHost=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${queueUser}" ]]; then
  echo "No RabbitMQ user specified!"
  usage
  exit 1
fi

if [[ -z "${queuePassword}" ]]; then
  echo "No RabbitMQ password specified!"
  usage
  exit 1
fi

if [[ -z "${queueVirtualHost}" ]]; then
  queueVirtualHost="/"
fi

if [[ -n "${queueUser}" ]] && [[ $(rabbitmqctl list_users 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -P "^${queueUser}$" | wc -l) -eq 0 ]]; then
  echo "Adding user: ${queueUser}"
  rabbitmqctl add_user "${queueUser}" "${queuePassword}"
  rabbitmqctl set_user_tags "${queueUser}" management
else
  echo "User: ${queueUser} already exists"
fi

if [[ -n "${queueVirtualHost}" ]] && [[ $(rabbitmqctl list_vhosts 2>/dev/null | tail -n +3 | awk '{print $1}' | grep "${queueVirtualHost}" | wc -l) -eq 0 ]]; then
  echo "Adding virtual host: ${queueVirtualHost}"
  rabbitmqctl add_vhost "${queueVirtualHost}"
else
  echo "Virtual host: ${queueVirtualHost} already exists"
fi

if [[ -n "${queueUser}" ]] && [[ -n "${queueVirtualHost}" ]] && [[ $(rabbitmqctl list_user_permissions "${queueUser}" 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -P "^${queueVirtualHost}$" | wc -l) -eq 0 ]]; then
  echo "Adding permission for user: ${queueUser} to virtual host: ${queueVirtualHost}"
  rabbitmqctl set_permissions -p "${queueVirtualHost}" "${queueUser}" ".*" ".*" ".*"
else
  echo "User: ${queueUser} already has permission to virtual host: ${queueVirtualHost}"
fi
