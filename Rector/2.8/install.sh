#!/bin/bash -e

# Rector is installed with Composer, PHP and Composer have to be installed first
cosyses --applicationName Composer --applicationScript tool.sh --packageName rector/rector --packageVersion "~2.8.0"
