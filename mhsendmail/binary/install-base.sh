#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the release binary of MailHog sendmail (a static Go binary) to /usr/bin/mhsendmail.

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

# Set by the version specific install.sh which sources this script, the full release, e.g. 0.2.0
if [[ -z "${mhsendmailVersion}" ]]; then
  >&2 echo "No mhsendmail version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

# The project only released binaries for 32 and 64 bit x86 and 32 bit ARM
architecture=$(uname -m)
if [[ "${architecture}" == "x86_64" ]]; then
  platform="linux_amd64"
elif [[ "${architecture}" == "i686" ]] || [[ "${architecture}" == "i386" ]]; then
  platform="linux_386"
else
  >&2 echo "Unsupported architecture: ${architecture}"
  exit 1
fi

if [[ -f /usr/bin/mhsendmail ]]; then
  echo "Mailhog sendmail already installed"
else
  downloadUrl="https://github.com/mailhog/mhsendmail/releases/download/v${mhsendmailVersion}/mhsendmail_${platform}"
  echo "Downloading mhsendmail ${mhsendmailVersion} from: ${downloadUrl}"
  wget -nv -O /usr/bin/mhsendmail "${downloadUrl}"
  chmod +x /usr/bin/mhsendmail
fi
