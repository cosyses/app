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
wget -q https://nodejs.org/dist/v18.18.2/node-v18.18.2.tar.gz
tar xfz node-v18.18.2.tar.gz
cd node-v18.18.2
./configure
make
make install
cd /
rm -rf /tmp/node.js

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/nodejs.sh"
  cat <<EOF > /usr/local/bin/nodejs.sh
#!/bin/bash -e
tail -f /dev/null
EOF
  chmod +x /usr/local/bin/nodejs.sh
fi

mkdir -p /opt/install/
crudini --set /opt/install/env.properties nodejs version "18.18"
