#!/bin/bash -e

install-package curl

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version 2.2.21
