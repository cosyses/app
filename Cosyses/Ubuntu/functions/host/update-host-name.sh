#!/bin/bash -e

hostName="${1}"
ipAddress="${2}"

if [[ -z "${ipAddress}" ]]; then
  ipAddress="127.0.0.1"
fi

if [ "$(grep -E "\s+${hostName}\s*$" /etc/hosts | wc -l)" -eq 0 ]; then
  echo "${ipAddress} ${hostName}" >> /etc/hosts
else
  lineNumber=$(grep -En "\s+${hostName}\s*$" /etc/hosts | awk -F: '{print $1}')
  sed -i "${lineNumber}s/.*/${ipAddress} ${hostName}/" /etc/hosts
fi
