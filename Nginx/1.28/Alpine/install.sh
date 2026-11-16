#!/bin/bash -e

nginxVersion="1.28"
nginxRepository="stable"
# nginx.org built the 1.28 line up to Alpine 3.23, the package works with the libraries of 3.24
nginxRepositoryRelease="3.23"

source "${cosysesPath}/Nginx/Alpine/install-base.sh"
