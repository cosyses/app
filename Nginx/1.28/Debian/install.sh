#!/bin/bash -e

# The packages of nginx.org for Debian, installed like on Ubuntu 24.04
nginxVersion="1.28"
nginxRepository="stable"
nginxPidFile="/run/nginx.pid"

source "${cosysesPath}/Nginx/Ubuntu/24.04/install-base.sh"
