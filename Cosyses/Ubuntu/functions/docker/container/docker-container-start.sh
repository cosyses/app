#!/bin/bash -e

containerName="${1}"

if [[ $(docker-container-exists "${containerName}") == 1 ]]; then
  echo "Starting container: ${containerName}"
  docker start "${containerName}"
fi
