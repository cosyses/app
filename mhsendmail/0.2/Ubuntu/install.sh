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
  --help  Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

cosyses \
  --applicationName Go \
  --applicationVersion 1.8

if [[ -f /usr/bin/mhsendmail ]]; then
  echo "Mailhog sendmail already installed"
else
  install-package git

  if [[ -f ~/.profile ]]; then
    source ~/.profile
  fi

  echo "Building mhsendmail"
  go get github.com/mailhog/mhsendmail

  cp /root/go/bin/mhsendmail /usr/bin/mhsendmail
fi
