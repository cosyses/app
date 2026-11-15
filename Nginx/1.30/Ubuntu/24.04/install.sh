#!/bin/bash -e

nginxVersion="1.30"
nginxRepository="stable"
nginxPidFile="/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/24.04/install-base.sh"
