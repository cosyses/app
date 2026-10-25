#!/bin/bash -e

nginxVersion="1.26"
nginxRepository="stable"
nginxPidFile="/var/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/22.04/install-base.sh"
