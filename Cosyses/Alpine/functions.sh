#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

installFunctions()
{
  local functionFiles
  local functionFile
  local functionScriptName
  mapfile -t functionFiles < <(find "${1}" -type f -name "*.sh")
  for functionFile in "${functionFiles[@]}"; do
    functionScriptName=$(basename "${functionFile}" | sed 's/\(.*\)\..*/\1/')
    cp "${functionFile}" "/usr/local/bin/${functionScriptName}"
    chmod +x "/usr/local/bin/${functionScriptName}"
  done
}

# The helpers of these groups only use bash and common tools, so Alpine uses the ones of Ubuntu
sharedGroups=( docker file host npm php pip ruby ssh user )
for sharedGroup in "${sharedGroups[@]}"; do
  installFunctions "${currentPath}/../Ubuntu/functions/${sharedGroup}"
done

# Package and repository helpers for apk
installFunctions "${currentPath}/functions"

release=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -f1-2 -d".")

if [[ -d "${currentPath}/${release}/functions" ]]; then
  installFunctions "${currentPath}/${release}/functions"
fi

# The helpers and scripts use the GNU tools (e.g. grep -P, sort -V) and the user commands of shadow
install-package bash
install-package coreutils
install-package findutils
install-package grep
install-package sed
install-package gawk
install-package shadow
install-package sudo
install-package curl
install-package wget
install-package ca-certificates
