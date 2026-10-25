#!/bin/bash -e

nginxVersion="1.28"
nginxRepository="stable"
nginxPidFile="/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/22.04/install-base.sh"
