#!/bin/bash -e

if [ "$(grep -e "de\." /etc/apt/sources.list | wc -l)" -gt 0 ]; then
  sed -i -e 's/de\.archive/archive/g' /etc/apt/sources.list
fi
mkdir -p /var/lib/apt/lists/partial
rm -rf /var/lib/apt/lists/partial/*
rm -rf /var/lib/apt/lists/lock
apt-get update || apt-get update || apt-get update
