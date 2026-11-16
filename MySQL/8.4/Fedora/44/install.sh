#!/bin/bash -e

# Fedora has packages of 8.4 itself, the packages of the MySQL project for Fedora 44 fail the signature check of dnf
mysqlVersion="8.4"
mysqlServerPackage="mysql-server"
mysqlClientPackage="mysql"
mysqlRepository=

source "${cosysesPath}/MySQL/RHEL/install-base.sh"
