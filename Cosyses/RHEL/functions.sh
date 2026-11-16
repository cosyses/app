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

# The helpers of these groups only use bash and common tools, so RHEL uses the ones of Ubuntu
sharedGroups=( docker file host npm php pip ruby ssh ssl user version )
for sharedGroup in "${sharedGroups[@]}"; do
  installFunctions "${currentPath}/../Ubuntu/functions/${sharedGroup}"
done

# Package helpers for dnf
installFunctions "${currentPath}/functions"

if [[ -n "${release}" ]] && [[ -d "${currentPath}/${release}/functions" ]]; then
  installFunctions "${currentPath}/${release}/functions"
fi

# Tools the helpers and scripts use, which the minimal images lack
install-package sudo
install-package findutils
install-package procps-ng
install-package which
install-package hostname
install-package tar
install-package gzip
install-package shadow-utils

source "${currentPath}/../RHEL/www-data.sh"
