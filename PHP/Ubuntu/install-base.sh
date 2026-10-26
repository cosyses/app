#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${phpVersion}" ]] || [[ -z "${phpTypes}" ]]; then
  >&2 echo "No PHP version or types set!"
  echo ""
  exit 1
fi

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
  --type  Type of installation (${phpTypes// /, }), default: cli

Example: ${scriptFileName} --type mod
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

type=
prepareParametersList=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${type}" ]]; then
  type="cli"
fi

if [[ " ${phpTypes} " =~ \ ${type}\  ]]; then
  source "${cosysesPath}/PHP/Ubuntu/install-base/${type}.sh" "${prepareParametersList[@]}"
else
  >&2 echo "Could not find PHP installation of type: ${type}"
  exit 1
fi
