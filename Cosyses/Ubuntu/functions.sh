#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

functionFiles=( $(find "${currentPath}/functions" -type f -name "*.sh") )

for functionFile in "${functionFiles[@]}"; do
  functionScriptName=$(basename "${functionFile}" | sed 's/\(.*\)\..*/\1/')
  cp "${functionFile}" "/usr/local/bin/${functionScriptName}"
  chmod +x "/usr/local/bin/${functionScriptName}"
done

release=$(lsb_release -r | awk '{print $2}' | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")

if [[ -d "${currentPath}/${release}/functions" ]]; then
  functionFiles=( $(find "${currentPath}/${release}/functions" -type f -name "*.sh") )

  for functionFile in "${functionFiles[@]}"; do
    functionScriptName=$(basename "${functionFile}" | sed 's/\(.*\)\..*/\1/')
    cp "${functionFile}" "/usr/local/bin/${functionScriptName}"
    chmod +x "/usr/local/bin/${functionScriptName}"
  done
fi

install-package sudo
install-package apt-utils
install-package dialog
