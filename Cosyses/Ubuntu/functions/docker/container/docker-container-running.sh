#!/bin/bash -e

containerName="${1}"

docker ps | grep -E "\\s${containerName}$" | wc -l
