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
content="${2}"
before="${3}"
lineBreak="${4}"

if [ "${lineBreak}" == 1 ]; then
  lineBreak="\\n"
else
  lineBreak=
fi

beforePattern=$(quoteRegex "${before}")
beforeContent=$(quoteInsert "${before}")
pregBeforePattern=$(pregQuoteRegex "${before}")
contentPattern=$(pregQuoteRegex "${content}")
content=$(quoteInsert "${content}")

if [ "$(grep -P "${pregBeforePattern}" "${fileName}" | wc -l)" -gt 0 ] && [ "$(grep -P "${contentPattern}$" "${fileName}" | wc -l)" -eq 0 ]; then
  echo "Insert: ${content}"
  sed -i -e "s/${beforePattern}/${content}${lineBreak}${beforeContent}/g" "${fileName}"
fi
