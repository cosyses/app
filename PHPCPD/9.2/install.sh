#!/bin/bash -e

# PHPCPD (copy/paste detector for PHP, maintained fork systemsdk/phpcpd, needs PHP 8.4 or newer) is installed with
# Composer, PHP and Composer have to be installed first
cosyses --applicationName Composer --applicationScript tool.sh --packageName systemsdk/phpcpd --packageVersion "~9.2.0" \
  --binaryNames phpcpd --phpExtensions mbstring,xml,dom
