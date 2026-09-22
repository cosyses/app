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
  --size  Value to set upload size to

Example: ${scriptFileName} --size 512M
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  usage
  exit 1
fi

size=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${size}" ]]; then
  >&2 echo "So size specified!"
  usage
  exit 1
fi

add-file-content-before /etc/nginx/nginx.conf "    client_max_body_size ${size};" "    include /etc/nginx/conf.d/*.conf;" 1

if [[ -f /.dockerenv ]]; then
  echo "Reloading Nginx"
  nginx -s reload
else
  echo "Restarting Nginx"
  service nginx restart
fi
