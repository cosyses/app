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

# Set by the version specific install.sh which sources this script: the version of the packages and the name of the
# client package (openssh-client on Debian, openssh-clients on RHEL, Fedora and openSUSE)
if [[ -z "${opensshVersion}" ]]; then
  >&2 echo "No OpenSSH version specified!"
  echo ""
  exit 1
fi

if [[ -z "${opensshClientPackage}" ]]; then
  >&2 echo "No OpenSSH client package specified!"
  echo ""
  exit 1
fi

port=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${port}" ]]; then
  port="22"
fi

install-package openssh-server "${opensshVersion}"
install-package "${opensshClientPackage}" "${opensshVersion}"

echo "Setting port: ${port}"
if [[ -f /etc/ssh/sshd_config ]]; then
  # Matches the commented default as well as a port set by an earlier run
  sed -i -E "s/^#?Port [0-9]+\$/Port ${port}/" /etc/ssh/sshd_config
else
  # openSUSE 16 keeps the default configuration in /usr/etc/ssh, which includes the files in /etc/ssh/sshd_config.d
  mkdir -p /etc/ssh/sshd_config.d
  echo "Port ${port}" > /etc/ssh/sshd_config.d/10-port.conf
fi

echo "Generating host keys"
ssh-keygen -A

# There is no init script on every distribution (RHEL, Fedora and openSUSE use systemd), the start script runs the
# server directly
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
ssh-keygen -A
# The privilege separation directory, Debian's sshd does not start without it
mkdir -p /run/sshd
echo "Starting OpenSSH"
/usr/sbin/sshd
EOF
chmod +x /usr/local/bin/openssh.sh

echo "Creating stop script at: /usr/local/bin/openssh-stop.sh"
cat <<EOF > /usr/local/bin/openssh-stop.sh
#!/bin/bash -e
if [[ -f /run/sshd.pid ]]; then
  echo "Stopping OpenSSH"
  kill "\$(cat /run/sshd.pid)" || true
fi
EOF
chmod +x /usr/local/bin/openssh-stop.sh
