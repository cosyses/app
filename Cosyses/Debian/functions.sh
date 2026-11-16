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

# Debian uses apt like Ubuntu, so it uses the helpers of Ubuntu, with keys in /etc/apt/keyrings as on Ubuntu 22.04
installFunctions "${currentPath}/../Ubuntu/functions"
installFunctions "${currentPath}/../Ubuntu/22.04/functions"
# Debian versions of single helpers (Debian 13 has no software-properties-common, which add-gpg-repository of Ubuntu
# installs for add-apt-repository)
installFunctions "${currentPath}/functions"

if [[ -n "${release}" ]] && [[ -d "${currentPath}/${release}/functions" ]]; then
  installFunctions "${currentPath}/${release}/functions"
fi

install-package sudo
install-package apt-utils
install-package dialog
# The Debian images have no ps and pgrep, unlike the Ubuntu images
install-package procps
