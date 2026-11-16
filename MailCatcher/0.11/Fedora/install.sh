#!/bin/bash -e

# MailCatcher 0.6 does not build with the Ruby of RHEL 10 and Fedora (eventmachine 1.0 and thin 1.5 fail with GCC 14)
mailcatcherVersion="0.11"
mailcatcherMimeTypesVersion=

source "${cosysesPath}/MailCatcher/RHEL/install-base.sh"
