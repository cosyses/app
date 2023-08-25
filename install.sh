#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi
cosysesPath=$(cd -P "$(dirname "${scriptFileName}")" && pwd)
export cosysesPath

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help                Show this message
  --applicationName     Name of application
  --applicationVersion  Version of application (optional)
  --applicationScript   Name of script, default: install.sh

Example: ${scriptFileName} --applicationName Elasticsearch --applicationVersion 7.9
EOF
}

applicationName=
applicationVersion=
applicationScript=
prepareParametersList=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${applicationName}" ]] && [[ -z "${applicationVersion}" ]] && [[ -z "${applicationScript}" ]]; then
  if [[ -n "${1}" ]]; then
    applicationName="${1}"
  fi
  if [[ -n "${2}" ]]; then
    applicationVersion="${2}"
  fi
  if [[ -n "${3}" ]]; then
    applicationScript="${3}"
  fi
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name specified!"
  usage
  exit 1
fi

if [[ -z "${applicationScript}" ]]; then
  applicationScript="install.sh"
fi

if [[ -n "${applicationVersion}" ]]; then
  echo "Installing application: ${applicationName} with version: ${applicationVersion} and script: ${applicationScript}"
else
  echo "Installing application: ${applicationName} with script: ${applicationScript}"
fi

distribution=$(lsb_release -i | awk '{print $3}')
release=$(lsb_release -r | awk '{print $2}' | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")

if [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}"
elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}"
elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}"
elif [[ -f "${cosysesPath}/${applicationName}/${distribution}/${release}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}/${distribution}/${release}"
elif [[ -f "${cosysesPath}/${applicationName}/${distribution}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}/${distribution}"
elif [[ -f "${cosysesPath}/${applicationName}/${applicationScript}" ]]; then
  applicationScriptPath="${cosysesPath}/${applicationName}"
elif [[ -z "${applicationVersion}" ]]; then
  if [[ -d "${cosysesPath}/${applicationName}" ]]; then
    applicationVersion=$(find "${cosysesPath}/${applicationName}"/* -maxdepth 1 -type d -exec basename {} \; | sort --version-sort | tail -n1 | tr -d '\r' | tr -d '\n')
    if [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}/${applicationScript}" ]]; then
      applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}"
    elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${applicationScript}" ]]; then
      applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}"
    elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${applicationScript}" ]]; then
      applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}"
    fi
  fi
fi

if [[ -z "${applicationScriptPath}" ]]; then
  if [[ -n "${applicationVersion}" ]]; then
    >&2 echo "Could not any find script to install application: ${applicationName} with version: ${applicationVersion} and script: ${applicationScript}"
  else
    >&2 echo "Could not any find script to install application: ${applicationName} with script: ${applicationScript}"
  fi
  exit 1
fi

export applicationScriptPath

source "${applicationScriptPath}/${applicationScript}" "${prepareParametersList[@]}"

if [[ -n "${applicationVersion}" ]]; then
  echo "Finished installing application: ${applicationName} with version: ${applicationVersion}"
else
  echo "Finished installing application: ${applicationName}"
fi
