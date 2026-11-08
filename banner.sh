#!/bin/bash -e

# Prints the Cosyses logo, sourced by install.sh (callers decide when and where to)

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  exit 1
fi

bannerAccent=
bannerDim=
bannerReset=
if [[ -z "${NO_COLOR}" ]] && [[ "${TERM}" != "dumb" ]]; then
  bannerAccent=$'\033[38;5;37m'
  bannerDim=$'\033[2m'
  bannerReset=$'\033[0m'
fi

# The installation directory is named after the release tag, e.g. /usr/local/lib/cosyses/1.119.0
bannerVersion=$(basename "${cosysesPath}")
if [[ ! "${bannerVersion}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  bannerVersion=
fi

a="${bannerAccent}"
r="${bannerReset}"
cat << EOF

   ▄▄██████▄▄
 ▄███▀▀▀▀▀▀███
▄██▀         ▀▀   ▄▀▀▀▀ ▄▀▀▀▄ ${a}▄▀▀▀▀ █   █ ▄▀▀▀▀${r} ▄▀▀▀▄ ▄▀▀▀▀
███  ${a}▀█▄${r}          █     █   █ ${a} ▀▀▀▄ █   █  ▀▀▀▄${r} █▀▀▀▀  ▀▀▀▄
███  ${a}▄█▀ ▄▄▄${r}      ▀▄▄▄▄ ▀▄▄▄▀ ${a}▄▄▄▄▀  ▀▀▀█ ▄▄▄▄▀${r} ▀▄▄▄▄ ▄▄▄▄▀
▀██▄         ▄▄                     ${a}▄▄▄▄▀${r}
 ▀███▄▄▄▄▄▄███
   ▀▀██████▀▀     ${bannerDim}reproducible install routines${bannerVersion:+ · ${bannerVersion}}${r}

EOF
unset a r bannerAccent bannerDim bannerReset bannerVersion
