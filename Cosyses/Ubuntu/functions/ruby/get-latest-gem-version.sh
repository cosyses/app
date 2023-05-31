#!/bin/bash -e

function quoteRegex()
{
  sed 's/[]\.\/|$(){}?+*^[]/\\&/g' <<< "$*" | sed 's/ /\\\s*/g'
}

gemName="${1}"

baseVersion=
if [ -z "${2}" ]; then
  baseVersion="[0-9]+\.[0-9]+"
else
  baseVersion=$(quoteRegex "${2}")
fi

versions=($(gem list --remote --all "${gemName}" | grep -P "^${gemName}\s" | grep -ohP "[0-9]+(\.[0-9]+)*" | grep -P "^${baseVersion}" | sort -rV))
latestVersion=${versions[0]}

echo "${latestVersion}"
