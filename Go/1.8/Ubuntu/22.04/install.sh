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

if [[ $(which go | wc -l) -gt 0 ]]; then
  echo "Go already installed"
else
  install-package ca-certificates
  install-package curl

  echo "Downloading Go"
  curl -Lsf 'https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz' | tar -C '/usr/local' -xvzf -

  if [[ -f ~/.profile ]]; then
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
    source ~/.profile
  else
    export PATH="${PATH}:/usr/local/go/bin"
  fi
fi
