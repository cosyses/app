#!/bin/bash -e

declare -Ag prepareParameters
prepareParametersList=()
prepareParametersListParts=()
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter}" =~ ^-[[:alpha:]]+ ]] || [[ "${parameter}" =~ ^--[[:alpha:]]+ ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^--[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^-[[:alpha:]]+[[:space:]]+ ]] || [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
        parameter="${parameter:2}"
      elif [[ "${parameter}" =~ ^-[[:alpha:]]+[[:space:]]+ ]]; then
        parameter="${parameter:1}"
      fi
      prepareParametersKey=$(echo "${parameter}" | grep -oP '[[:alpha:]]+(?=\s)' | tr -d "\n")
      prepareParametersValue=$(echo "${parameter:${#prepareParametersKey}}" | xargs)
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      prepareParametersList+=( "--${prepareParametersKey} ${prepareParametersValue}" )
      prepareParametersListParts+=( "--${prepareParametersKey}" )
      prepareParametersListParts+=( "${prepareParametersValue}" )
      continue
    fi
    skipParameter=0
    if [[ "${parameter:0:2}" == "--" ]]; then
      prepareParametersKey="${parameter:2}"
    elif [[ "${parameter}" =~ ^-\?$ ]]; then
      prepareParametersKey="help"
    else
      prepareParametersKey="${parameter:1}"
      skipParameter=1
    fi
    if [[ "$#" -eq 0 ]]; then
      if [[ "${skipParameter}" == 0 ]]; then
        prepareParameters["${prepareParametersKey}"]=1
        eval "${prepareParametersKey}=1"
        #echo eval "${prepareParametersKey}=1"
        prepareParametersList+=( "--${prepareParametersKey}" )
        prepareParametersListParts+=( "--${prepareParametersKey}" )
        prepareParametersListParts+=( "1" )
      fi
    else
      prepareParametersValue="${1}"
      if [[ "${prepareParametersValue}" =~ ^-[[:alpha:]]+ ]] || [[ "${prepareParametersValue}" =~ ^--[[:alpha:]]+ ]]; then
        if [[ "${skipParameter}" == 0 ]]; then
          prepareParameters["${prepareParametersKey}"]=1
          eval "${prepareParametersKey}=1"
          #echo eval "${prepareParametersKey}=1"
          prepareParametersList+=( "--${prepareParametersKey}" )
          prepareParametersListParts+=( "--${prepareParametersKey}" )
          prepareParametersListParts+=( "1" )
        fi
        continue
      fi
      shift
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      prepareParametersList+=( "--${prepareParametersKey} ${prepareParametersValue}" )
      prepareParametersListParts+=( "--${prepareParametersKey}" )
      prepareParametersListParts+=( "${prepareParametersValue}" )
    fi
  else
    unparsedParameters+=("${parameter}")
  fi
done
set -- "${unparsedParameters[@]}"

if test "${prepareParameters["help"]+isset}" || test "${prepareParameters["?"]+isset}"; then
  helpRequested=1
  if ! test "${prepareParameters["applicationName"]+isset}" && [[ "${#unparsedParameters[@]}" -eq 0 ]] && [[ $(declare -F "usage" | wc -l) -gt 0 ]]; then
    usage
    exit 0
  fi
else
  helpRequested=0
fi
export helpRequested
