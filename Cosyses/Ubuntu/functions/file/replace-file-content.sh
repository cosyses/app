#!/bin/bash -e

function quoteInsert()
{
  sed 's/\//\\&/g' <<< "$*" | sed 's/"/\\&/g'
}

function quoteRegex()
{
  sed 's/[]\.\/|$(){}?+*^[]/\\&/g' <<< "$*" | sed 's/ /\\\s*/g' | sed 's/"/\\&/g'
}

function pregQuoteRegex()
{
  # shellcheck disable=SC2005
  echo "$(quoteRegex "$*")" | sed s/^-/\\\\-/g
}

fileName="${1}"
replace="${2}"
find="${3}"
checkReplaced="${4:-1}"

findPattern=$(quoteRegex "${find}")
pregFindPattern=$(pregQuoteRegex "${find}")
replacePattern=$(pregQuoteRegex "${replace}")
replace=$(quoteInsert "${replace}")

if [ "$(grep -P "${pregFindPattern}" "${fileName}" | wc -l)" -gt 0 ] && { [ "${checkReplaced}" -eq 0 ] || [ "$(grep -P "${replacePattern}" "${fileName}" | wc -l)" -eq 0 ]; }; then
  echo "Replace: ${findPattern} with: ${replace}"
  sed -i -e "s/${findPattern}/${replace}/g" "${fileName}"
fi
