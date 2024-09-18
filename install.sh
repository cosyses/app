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

usage: cosyses [options]

MODE:

OPTIONS:
  --help                Show this message
  --applicationName     Name of application
  --applicationVersion  Version of application (optional)
  --applicationScript   Name of script, default: install.sh

Example: cosyses --applicationName Elasticsearch --applicationVersion 7.9
Short: cosyses Elasticsearch 7.9
EOF
}

applicationName=
applicationVersion=
applicationScript=
prepareParametersList=
helpRequested=
source "${cosysesPath}/prepare-parameters.sh"

distribution=$(lsb_release -i | awk '{print $3}')
release=$(lsb_release -r | awk '{print $2}' | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")

if [[ -z "${applicationName}" ]] && [[ -z "${applicationVersion}" ]] && [[ -z "${applicationScript}" ]]; then
  if [[ -n "${1}" ]] && [[ "${1}" == "list" ]]; then
    cd "${cosysesPath}"
    if [[ -z "${2}" ]]; then
      applicationNames=( $(find . -mindepth 1 -maxdepth 1 -type d ! -name .idea ! -name .git | cut -c 3- | sort -n) )
      for applicationName in "${applicationNames[@]}"; do
        applicationAvailable=0
        cd "${cosysesPath}/${applicationName}"
        applicationVersions=( $(find . -mindepth 1 -maxdepth 1 -type d ! -name .idea ! -name .git | cut -c 3- | sort -n) )
        for applicationVersion in "${applicationVersions[@]}"; do
          if [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}/install.sh" ]] ||
            [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/install.sh" ]] ||
            [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/install.sh" ]] ||
            [[ -f "${cosysesPath}/${applicationName}/${distribution}/${release}/install.sh" ]] ||
            [[ -f "${cosysesPath}/${applicationName}/${distribution}/install.sh" ]] ||
            [[ -f "${cosysesPath}/${applicationName}/install.sh" ]]; then
            applicationAvailable=1
          fi
        done
        if [[ "${applicationAvailable}" == 1 ]]; then
          echo "${applicationName}"
        fi
      done
    else
      applicationName="${2}"
      cd "${cosysesPath}/${applicationName}"
      applicationVersions=( $(find . -mindepth 1 -maxdepth 1 -type d ! -name .idea ! -name .git | cut -c 3- | sort -n) )
      for applicationVersion in "${applicationVersions[@]}"; do
        if [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}/install.sh" ]] ||
          [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/install.sh" ]] ||
          [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/install.sh" ]] ||
          [[ -f "${cosysesPath}/${applicationName}/${distribution}/${release}/install.sh" ]] ||
          [[ -f "${cosysesPath}/${applicationName}/${distribution}/install.sh" ]] ||
          [[ -f "${cosysesPath}/${applicationName}/install.sh" ]]; then
          echo "${applicationVersion}"
        fi
      done
    fi
    exit 0
  else
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
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name specified!"
  usage
  exit 1
fi

if [[ -z "${applicationScript}" ]]; then
  applicationScript="install.sh"
fi

if [[ "${helpRequested}" == 0 ]]; then
  if [[ -n "${applicationVersion}" ]]; then
    echo "Installing application: ${applicationName} with version: ${applicationVersion} and script: ${applicationScript}"
  else
    echo "Installing application: ${applicationName} with script: ${applicationScript}"
  fi
fi

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
  applicationScriptPath=
  if [[ -d "${cosysesPath}/${applicationName}" ]]; then
    applicationVersions=( $(find "${cosysesPath}/${applicationName}"/* -mindepth 0 -maxdepth 0 -type d -exec basename {} \; | sort --version-sort -r ) )
    for applicationVersion in "${applicationVersions[@]}"; do
      if [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}/${applicationScript}" ]]; then
        applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${release}"
        break
      elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}/${applicationScript}" ]]; then
        applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}/${distribution}"
        break
      elif [[ -n "${applicationVersion}" ]] && [[ -f "${cosysesPath}/${applicationName}/${applicationVersion}/${applicationScript}" ]]; then
        applicationScriptPath="${cosysesPath}/${applicationName}/${applicationVersion}"
        break
      fi
    done
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

export applicationName
export applicationVersion
export applicationScriptPath

source "${applicationScriptPath}/${applicationScript}" "${prepareParametersList[@]}"

if [[ -n "${applicationVersion}" ]]; then
  if [[ -n "${applicationScript}" ]]; then
    echo "Finished installing application: ${applicationName} with version: ${applicationVersion} and script: ${applicationScript}"
  else
    echo "Finished installing application: ${applicationName} with version: ${applicationVersion}"
  fi
else
  echo "Finished installing application: ${applicationName}"
fi
