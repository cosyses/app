#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Chrome for Testing (the Chromium based browser build for automation) as: chromium and chrome

Chrome's sandbox needs user namespaces or its setuid helper (installed as chrome-sandbox). Both work on servers. In a
container they need the capability SYS_ADMIN (docker run --cap-add SYS_ADMIN), otherwise start Chrome with --no-sandbox.
As root Chrome always needs --no-sandbox.

OPTIONS:
  --help Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

# Chrome for Testing keeps the downloads of all versions, unlike the Ubuntu snap and the PPAs, so this version stays installable
chromeVersion="156.0.8078.80"

architecture=$(dpkg --print-architecture)
if [[ "${architecture}" == "amd64" ]]; then
  platform="linux64"
elif [[ "${architecture}" == "arm64" ]]; then
  platform="linux-arm64"
else
  >&2 echo "Unsupported architecture: ${architecture}"
  exit 1
fi

installPath="/opt/chrome-for-testing/${chromeVersion}"

if [[ -x "${installPath}/chrome" ]]; then
  echo "Chrome for Testing ${chromeVersion} already installed at: ${installPath}"
else
  install-package wget
  install-package unzip
  downloadPath=$(mktemp -d)
  downloadUrl="https://storage.googleapis.com/chrome-for-testing-public/${chromeVersion}/${platform}/chrome-${platform}.zip"
  echo "Downloading Chrome for Testing ${chromeVersion} from: ${downloadUrl}"
  wget -nv -O "${downloadPath}/chrome.zip" "${downloadUrl}"
  echo "Extracting to: ${installPath}"
  unzip -q "${downloadPath}/chrome.zip" -d "${downloadPath}"
  mkdir -p "$(dirname "${installPath}")"
  rm -rf "${installPath}"
  mv "${downloadPath}/chrome-${platform}" "${installPath}"
  rm -rf "${downloadPath}"
fi

# The archive lists the packages it needs in the format of Debian dependencies
echo "Installing required packages"
update-packages
DEBIAN_FRONTEND=noninteractive apt-get satisfy -y "$(paste -sd, "${installPath}/deb.deps")" 2>&1

# Chrome uses the setuid sandbox helper next to its binary when user namespaces are not available (Ubuntu 23.10+ restricts them)
echo "Installing sandbox helper at: ${installPath}/chrome-sandbox"
cp "${installPath}/chrome_sandbox" "${installPath}/chrome-sandbox"
chown root:root "${installPath}/chrome-sandbox"
chmod 4755 "${installPath}/chrome-sandbox"

echo "Linking chromium and chrome to: ${installPath}/chrome"
ln -sfn "${installPath}/chrome" /usr/local/bin/chromium
ln -sfn "${installPath}/chrome" /usr/local/bin/chrome
