#!/bin/bash -e

imageName="${1}"
imageVersion="${2}"

if [[ $(docker-image-exists "${imageName}" "${imageVersion}") == 1 ]]; then
  echo "Removing image: ${imageName}:${imageVersion}"
  docker image rm "${imageName}:${imageVersion}"
fi
