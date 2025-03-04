#!/bin/bash -e

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)

if [[ -z "${phpVersion}" ]]; then
  >&2 echo "PHP not found"
  exit 1
fi

install-package "php${phpVersion}-xml"

pear install PHP_CodeSniffer-2.8.1
