#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

functionFiles=( $(find "${currentPath}/functions" -type f -name "*.sh") )

for functionFile in "${functionFiles[@]}"; do
  functionScriptName=$(basename "${functionFile}" | sed 's/\(.*\)\..*/\1/')
  cp "${functionFile}" "/usr/local/bin/${functionScriptName}"
  chmod +x "/usr/local/bin/${functionScriptName}"
done
