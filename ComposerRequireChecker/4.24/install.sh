#!/bin/bash -e

# ComposerRequireChecker (checks that every class, function and constant used by the code comes from a dependency in
# composer.json, needs PHP 8.4 or newer) is installed with Composer, PHP and Composer have to be installed first; its
# PHP Standard Library needs the extensions bcmath, intl and mbstring
cosyses --applicationName Composer --applicationScript tool.sh --packageName maglnet/composer-require-checker \
  --packageVersion "~4.24.0" --phpExtensions bcmath,intl,mbstring
