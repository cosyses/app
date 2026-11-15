#!/bin/bash -e

# Newer releases (Ubuntu 24.04, Debian 12) have their sources in /etc/apt/sources.list.d/*.sources instead
if [ -f /etc/apt/sources.list ] && [ "$(grep -e "de\." /etc/apt/sources.list | wc -l)" -gt 0 ]; then
  sed -i -e 's/de\.archive/archive/g' /etc/apt/sources.list
fi
mkdir -p /var/lib/apt/lists/partial
rm -rf /var/lib/apt/lists/partial/*
rm -rf /var/lib/apt/lists/lock
apt-get update --allow-releaseinfo-change || apt-get update --allow-releaseinfo-change || apt-get update --allow-releaseinfo-change
