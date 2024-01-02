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

add-gpg-repository nodejs.list https://deb.nodesource.com/node_18.x nodistro main https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key

install-package nodejs 18.18

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/nodejs.sh"
  cat <<EOF > /usr/local/bin/nodejs.sh
#!/bin/bash -e
tail -f /dev/null
EOF
  chmod +x /usr/local/bin/nodejs.sh
fi
