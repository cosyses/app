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

install-package build-essential

mkdir -p /tmp/node.js
cd /tmp/node.js
wget -q https://nodejs.org/dist/v17.9.1/node-v17.9.1.tar.gz
tar xfz node-v17.9.1.tar.gz
cd node-v17.9.1
./configure
make
make install
cd /
rm -rf /tmp/node.js

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
