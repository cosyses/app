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
  --type  Type of installation (fpm, mod)

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
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${type}" ]]; then
  >&2 echo "No type of installation specified!"
  echo ""
  usage
  exit 1
fi

if [[ -f "${applicationScriptPath}/install/${type}.sh" ]]; then
  source "${applicationScriptPath}/install/${type}.sh"
fi
