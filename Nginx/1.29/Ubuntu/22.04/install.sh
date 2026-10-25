#!/bin/bash -e

nginxVersion="1.29"
nginxRepository="mainline"
nginxPidFile="/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/22.04/install-base.sh"
