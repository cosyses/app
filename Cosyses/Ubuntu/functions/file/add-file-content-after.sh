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
after="${3}"
lineBreak="${4}"

if [ "${lineBreak}" == 1 ]; then
  lineBreak="\\n"
else
  lineBreak=
fi

afterPattern=$(quoteRegex "${after}")
afterContent=$(quoteInsert "${after}")
pregAfterPattern=$(pregQuoteRegex "${after}")
contentPattern=$(pregQuoteRegex "${content}")
content=$(quoteInsert "${content}")

if [ "$(grep -P "${pregAfterPattern}" "${fileName}" | wc -l)" -gt 0 ] && [ "$(grep -P "${contentPattern}$" "${fileName}" | wc -l)" -eq 0 ]; then
  echo "Insert: ${content}"
  sed -i -e "s/${afterPattern}/${afterContent}${lineBreak}${content}/g" "${fileName}"
fi
