#!/bin/bash -e

hostName="${1}"
ipAddress="${2}"

if [[ -z "${ipAddress}" ]]; then
  ipAddress="127.0.0.1"
fi

if [ "$(grep -F "${ipAddress} ${hostName}" /etc/hosts | wc -l)" -eq 0 ]; then
  echo "${ipAddress} ${hostName}" >> /etc/hosts
fi
