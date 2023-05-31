#!/bin/bash -e

imageName="${1}"
shift
containerName="${1}"
shift
ports=("$@")

if [[ $(docker-container-running "${containerName}") == 0 ]]; then
  command="docker create"
  for port in "${ports[@]}"; do
    command+=" -p ${port}"
  done
  command+=" --name \"${containerName}\" \"${imageName}\""
  echo "Creating container: ${containerName} with image: ${imageName}"
  bash -c "${command}"
fi
