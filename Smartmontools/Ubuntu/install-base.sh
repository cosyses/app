#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs smartctl (reads the health data of SATA, SAS and NVMe drives) and the smartd monitoring daemon from the packages of the release.

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
if [[ -z "${smartmontoolsVersion}" ]]; then
  >&2 echo "No smartmontools version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

install-package smartmontools "${smartmontoolsVersion}"
