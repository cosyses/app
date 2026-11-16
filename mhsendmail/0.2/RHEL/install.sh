#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Builds mhsendmail 0.2.0 with the Go of the distribution (its modules are checked against the Go checksum database) and
removes Go afterwards.

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

if [[ -f /usr/bin/mhsendmail ]]; then
  echo "Mailhog sendmail already installed"
else
  goInstalled=$(get-installed-package-version golang)
  install-package golang

  buildPath=$(mktemp -d)
  echo "Building mhsendmail"
  GOPATH="${buildPath}" GOCACHE="${buildPath}/cache" GO111MODULE=on go install github.com/mailhog/mhsendmail@v0.2.0
  cp "${buildPath}/bin/mhsendmail" /usr/bin/mhsendmail
  chmod -R u+w "${buildPath}"
  rm -rf "${buildPath}"

  if [[ -z "${goInstalled}" ]]; then
    purge-package golang
    clean-packages
  fi
fi
