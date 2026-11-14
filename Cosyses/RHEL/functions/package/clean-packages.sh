#!/bin/bash -e

dnf autoremove -y 2>&1
dnf clean all 2>&1
