#!/bin/bash -e

nginxVersion="1.25"
nginxRepository="mainline"
nginxPidFile="/var/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/22.04/install-base.sh"
