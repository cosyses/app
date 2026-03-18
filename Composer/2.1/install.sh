#!/bin/bash -e

install-package curl

phpVersion=$(php -v 2>/dev/null | grep --only-matching --perl-regexp "(PHP )\d+\.\\d+\.\\d+" | cut -c 5-7)
install-package "php${phpVersion}-curl"

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version 2.1.14
