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
  --port  Port, default: 22

Example: ${scriptFileName} --port 2222
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${port}" ]]; then
  port="22"
fi

install-package openssh-server 1:8.9

replace-file-content /etc/ssh/sshd_config "Port ${port}" "#Port 22" 0

echo "Creating start script at: /usr/local/bin/openssh.sh"
cat <<EOF > /usr/local/bin/openssh.sh
#!/bin/bash -e
if [[ -d /usr/local/etc/ssh ]]; then
  userPaths=( \$(find /usr/local/etc/ssh -mindepth 1 -maxdepth 1 -type d) )
  for userPath in "\${userPaths[@]}"; do
    userName=\$(basename "\${userPath}")
    echo "Adding public keys of user: \${userName}"
    keyFiles=( \$(find "\${userPath}" -type f -name "*.pub") )
    for keyFile in "\${keyFiles[@]}"; do
      add-ssh-key "\${keyFile}" "\${userName}"
    done
  done
else
  echo "No public keys to add"
fi
/etc/init.d/ssh start
EOF
chmod +x /usr/local/bin/openssh.sh
