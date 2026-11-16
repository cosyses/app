#!/bin/bash -e

# The MySQL project has no repository for Fedora 45 (yet), Fedora has packages of 8.4 itself
mysqlVersion="8.4"
mysqlServerPackage="mysql8.4-server"
mysqlClientPackage="mysql8.4"
mysqlRepository=

source "${cosysesPath}/MySQL/RHEL/install-base.sh"
