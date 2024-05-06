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
  --help         Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

update-packages

install-package build-essential
install-package zlib1g-dev
install-package libncurses5-dev
install-package libgdbm-dev
install-package libnss3-dev
install-package libssl-dev
install-package libreadline-dev
install-package libffi-dev
install-package pkg-config
install-package wget

mkdir -p /tmp/python
cd /tmp/python
wget https://www.python.org/ftp/python/3.12.3/Python-3.12.3.tgz
tar -xvf Python-3.12.3.tgz
cd Python-3.12.3
./configure --enable-optimizations
make install

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/python.sh"
  cat <<EOF > /usr/local/bin/python.sh
#!/bin/bash -e
tail -f /dev/null
EOF
  chmod +x /usr/local/bin/python.sh
fi
