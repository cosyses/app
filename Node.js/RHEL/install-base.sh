#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Node.js from the RPM repository of NodeSource, which keeps all versions of a major version.

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

# Set by the version specific install.sh which sources this script
if [[ -z "${nodejsVersion}" ]]; then
  >&2 echo "No Node.js version specified!"
  echo ""
  exit 1
fi

# The repository of the NodeSource setup script, it can have another major version
if [[ -f /etc/yum.repos.d/nodesource-nodejs.repo ]]; then
  echo "Removing NodeSource repository at: /etc/yum.repos.d/nodesource-nodejs.repo"
  rm -f /etc/yum.repos.d/nodesource-nodejs.repo
fi

# The priority hides the Node.js packages of the distribution, module_hotfixes the module streams of RHEL
add-dnf-repository nodesource "https://rpm.nodesource.com/pub_${nodejsVersion%%.*}.x/nodistro/nodejs/\$basearch" https://rpm.nodesource.com/gpgkey/ns-operations-public.key module_hotfixes=1 priority=9

install-package nodejs "${nodejsVersion}"

echo "Installed Node.js $(node --version) with npm $(npm --version)"

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
