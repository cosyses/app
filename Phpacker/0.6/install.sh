#!/bin/bash -e

# phpacker (packs a PHAR together with a static PHP binary into executables for Linux, macOS and Windows) is installed
# with Composer, PHP and Composer have to be installed first
cosyses --applicationName Composer --applicationScript tool.sh --packageName phpacker/phpacker --packageVersion "~0.6.0" \
  --phpExtensions mbstring,zip
