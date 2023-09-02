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
  --help        Show this message
  --serverName  Server name
  --overwrite   Overwrite existing files (yes/no), default: no
  --append      Append to existing configuration if configuration file already exists (yes/no), default: no

Example: ${scriptFileName} --serverName project01.net
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

serverName=
overwrite=
append=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${overwrite}" ]]; then
  overwrite="no"
fi

if [[ "${overwrite}" == 1 ]]; then
  overwrite="yes"
fi

if [[ -z "${append}" ]]; then
  append="no"
fi

configurationFile="/etc/apache2/sites-available/${serverName}.conf"

if [[ -f "${configurationFile}" ]]; then
  if [[ "${overwrite}" == "no" ]] && [[ "${append}" == "no" ]]; then
    echo "Configuration \"${configurationFile}\" already exists"
    exit 1
  fi
  if [[ "${overwrite}" == "yes" ]]; then
    echo "Removing previous configuration file at: ${configurationFile}"
    rm -rf "${configurationFile}"
    echo "Creating configuration at: ${configurationFile}"
    touch "${configurationFile}"
  fi
else
  echo "Creating configuration at: ${configurationFile}"
  touch "${configurationFile}"
fi
