#!/bin/bash -e

containerName="${1}"

if [[ $(docker-container-running "${containerName}") == 1 ]]; then
  echo "Stopping container: ${containerName}"
  docker stop "${containerName}"
fi
