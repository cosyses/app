#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Node.js with npm from the musl builds of the Node.js project to /usr/local.

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

# Set by the version specific install.sh which sources this script, the full version, e.g. 24.13.1
if [[ -z "${nodejsVersion}" ]]; then
  >&2 echo "No Node.js version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

architecture=$(uname -m)
if [[ "${architecture}" == "x86_64" ]]; then
  platform="linux-x64-musl"
elif [[ "${architecture}" == "aarch64" ]]; then
  platform="linux-arm64-musl"
else
  >&2 echo "Unsupported architecture: ${architecture}"
  exit 1
fi

# The musl builds need the C++ runtime
install-package libstdc++
install-package libgcc
install-package xz
install-package tar

if [[ "$(/usr/local/bin/node --version 2>/dev/null)" == "v${nodejsVersion}" ]]; then
  echo "Node.js ${nodejsVersion} already installed"
else
  # The Node.js project keeps the builds of all versions, so this version stays installable
  downloadUrl="https://unofficial-builds.nodejs.org/download/release/v${nodejsVersion}"
  fileName="node-v${nodejsVersion}-${platform}.tar.xz"
  downloadPath=$(mktemp -d)

  echo "Downloading Node.js ${nodejsVersion} from: ${downloadUrl}/${fileName}"
  wget -nv -O "${downloadPath}/${fileName}" "${downloadUrl}/${fileName}"
  wget -q -O "${downloadPath}/SHASUMS256.txt" "${downloadUrl}/SHASUMS256.txt"

  echo "Verifying checksum"
  (cd "${downloadPath}" && grep " ${fileName}\$" SHASUMS256.txt | sha256sum -c -)

  echo "Extracting to: /usr/local"
  tar -xJf "${downloadPath}/${fileName}" -C /usr/local --strip-components=1 --no-same-owner --exclude='*/CHANGELOG.md' --exclude='*/LICENSE' --exclude='*/README.md'
  rm -rf "${downloadPath}"
fi

echo "Installed Node.js $(/usr/local/bin/node --version) with npm $(/usr/local/bin/npm --version)"

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
