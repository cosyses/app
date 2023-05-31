#!/bin/bash -e

containerName="${1}"
localFileName="${2}"
remoteFileName="${3}"

if [[ -z "${remoteFileName}" ]]; then
  remoteFileName=$(basename "${localFileName}")
fi

if [[ $(docker-container-running "${containerName}") == 1 ]]; then
  docker cp "${localFileName}" "${containerName}:${remoteFileName}"
fi
