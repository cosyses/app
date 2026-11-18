#!/bin/bash -e

# The deprecation rules of PHPStan (report the use of deprecated classes, methods, functions, constants and properties)
# are installed with Composer together with PHPStan 2, PHP and Composer have to be installed first; the binary phpstan
# of this installation is linked, the rules are included with
# /usr/local/lib/composer-tools/phpstan-deprecation-rules/vendor/phpstan/phpstan-deprecation-rules/rules.neon
cosyses --applicationName Composer --applicationScript tool.sh --packageName phpstan/phpstan-deprecation-rules \
  --packageVersion "~2.0.5" --binaryNames phpstan
