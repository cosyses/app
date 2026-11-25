#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the OpenVPN daemon and Easy-RSA (creates the certificate authority, server and client certificates) from the packages of the release. Only installs: no server configuration, no service is started.

OPTIONS:
  --help Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

# Set by the version specific install.sh which sources this script
if [[ -z "${openvpnVersion}" ]]; then
  >&2 echo "No OpenVPN version specified!"
  echo ""
  exit 1
fi

if [[ -z "${easyrsaVersion}" ]]; then
  >&2 echo "No Easy-RSA version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

install-package openvpn "${openvpnVersion}"
install-package easy-rsa "${easyrsaVersion}"
