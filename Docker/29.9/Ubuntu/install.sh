#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Docker Engine with the Buildx and Compose plugins from the Docker repository.

OPTIONS:
  --help      Show this message
  --userName  User to add to the docker group (optional)

Example: ${scriptFileName} --userName deploy
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

userName=
source "${cosysesPath}/prepare-parameters.sh"

# The Docker repository keeps all previous versions, so these stay installable
dockerVersion="5:29.9"
containerdVersion="2.4"
buildxVersion="0.38"
composeVersion="5.7"

add-asc-repository "docker.list" "https://download.docker.com/linux/ubuntu" "$(lsb_release -cs)" "stable" "https://download.docker.com/linux/ubuntu/gpg"

install-package containerd.io "${containerdVersion}"
install-package docker-ce-cli "${dockerVersion}"
install-package docker-ce "${dockerVersion}"
install-package docker-buildx-plugin "${buildxVersion}"
install-package docker-compose-plugin "${composeVersion}"

if [[ -n "${userName}" ]]; then
  echo "Adding user: ${userName} to group: docker"
  usermod -a -G docker "${userName}"
fi
