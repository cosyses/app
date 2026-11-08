#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

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

source "${cosysesPath}/prepare-parameters.sh"

# Ubuntu only ships Chromium as a snap, which does not work in containers, the xtradeb PPA provides it as deb package
add-ppa-repository "ppa:xtradeb/apps"

# The PPA contains many applications, it must not replace packages of Ubuntu
echo "Creating apt preferences at: /etc/apt/preferences.d/xtradeb-apps"
cat <<EOF > /etc/apt/preferences.d/xtradeb-apps
Package: *
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 100
EOF

install-package chromium 156.0
