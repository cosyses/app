#!/bin/bash -e

containerName="${1}"

if [[ $(docker-container-exists "${containerName}") == 1 ]]; then
  echo "Removing container: ${containerName}"
  docker rm "${containerName}"
fi
