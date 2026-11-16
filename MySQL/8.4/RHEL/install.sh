#!/bin/bash -e

# The repository of the MySQL project keeps the packages of all versions of 8.4
mysqlVersion="8.4"
mysqlServerPackage="mysql-community-server"
mysqlClientPackage="mysql-community-client"
mysqlRepository="mysql-8.4-community/el/$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -d. -f1)"

source "${cosysesPath}/MySQL/RHEL/install-base.sh"
