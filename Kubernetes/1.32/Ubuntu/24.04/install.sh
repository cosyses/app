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

add-gpg-repository \
  kubernetes.list \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ \
  / \
  / \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key

install-package kubelet
install-package kubeadm
install-package kubectl

apt-mark hold kubelet
apt-mark hold kubeadm
apt-mark hold kubectl

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
