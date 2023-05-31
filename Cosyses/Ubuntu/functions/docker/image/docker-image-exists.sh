#!/bin/bash -e

imageName="${1}"
imageVersion="${2}"

docker images | grep -E "^${imageName}\\s+${imageVersion}\\s" | wc -l
