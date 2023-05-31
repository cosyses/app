#!/bin/bash -e

containerName="${1}"

docker ps -a | grep -E "\\s${containerName}$" | wc -l
