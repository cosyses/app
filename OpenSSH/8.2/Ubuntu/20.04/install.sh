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
  --help  Show this message
  --port  Port, default: 22

Example: ${scriptFileName} --port 2222
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${port}" ]]; then
  port="22"
fi

install-package openssh-server 1:8.2

replace-file-content /etc/ssh/sshd_config "Port ${port}" "#Port 22" 0
