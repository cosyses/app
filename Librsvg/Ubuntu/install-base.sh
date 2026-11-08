#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs rsvg-convert (draws SVG files as PNG, PDF or PS) and DejaVu fonts, so that text in SVG files renders.

OPTIONS:
  --help Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

# Set by the version specific install.sh which sources this script
if [[ -z "${librsvgVersion}" ]]; then
  >&2 echo "No librsvg version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

install-package librsvg2-bin "${librsvgVersion}"
install-package fonts-dejavu-core
