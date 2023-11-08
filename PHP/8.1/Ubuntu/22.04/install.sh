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
  --type  Type of installation (cli, fpm, mod), default: cli

Example: ${scriptFileName} --type mod
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

if [[ -z "${applicationScriptPath}" ]]; then
  >&2 echo "No application script path exported!"
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

if [[ -f "${applicationScriptPath}/install/${type}.sh" ]]; then
  source "${applicationScriptPath}/install/${type}.sh" "${prepareParametersList[@]}"
else
  >&2 echo "Could not find PHP installation of type: ${type}"
  exit 1
fi
