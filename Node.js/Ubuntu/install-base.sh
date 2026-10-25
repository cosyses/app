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

# Set by the version specific install.sh which sources this script
if [[ -z "${nodejsVersion}" ]]; then
  >&2 echo "No Node.js version specified!"
  echo ""
  exit 1
fi

# Versions without NodeSource packages are built from source
if [[ -n "${nodejsBuildVersion}" ]]; then
  install-package build-essential

  mkdir -p /tmp/node.js
  cd /tmp/node.js
  wget -q "https://nodejs.org/dist/v${nodejsBuildVersion}/node-v${nodejsBuildVersion}.tar.gz"
  tar xfz "node-v${nodejsBuildVersion}.tar.gz"
  cd "node-v${nodejsBuildVersion}"
  ./configure
  make -j"$(nproc)"
  make install
  cd /
  rm -rf /tmp/node.js
else
  add-gpg-repository nodejs.list "https://deb.nodesource.com/node_${nodejsVersion%%.*}.x" nodistro main https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key

  install-package nodejs "${nodejsVersion}"
fi

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/nodejs.sh"
  cat <<EOF > /usr/local/bin/nodejs.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Node.js"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Node.js"
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/nodejs.sh
fi
