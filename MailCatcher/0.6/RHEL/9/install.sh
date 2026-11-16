#!/bin/bash -e

# The last version of 0.6, its dependencies (eventmachine 1.0, thin 1.5) only build with the Ruby 3.0 of RHEL 9
mailcatcherVersion="0.6.5"
mailcatcherMimeTypesVersion="2.99.1"

source "${cosysesPath}/MailCatcher/RHEL/install-base.sh"
