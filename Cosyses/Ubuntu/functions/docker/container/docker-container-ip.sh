#!/bin/bash -e

containerName="${1}"

docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${containerName}"
