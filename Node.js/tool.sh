#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs a command line tool that is distributed as npm package (for example eslint) into its own directory below
/usr/local/lib/npm-tools and links its binaries to /usr/local/bin. Node.js has to be installed (cosyses Node.js
<version>). An existing installation of the tool is replaced.

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --packageName     Name of the npm package, for example: eslint
  --packageVersion  Version range, for example: ~10.14.0
  --binaryNames     Comma separated names of the binaries in node_modules/.bin to link, default: name of the package
                    without scope
  --toolName        Name of the directory below /usr/local/lib/npm-tools, default: name of the package without scope

Example: ${scriptFileName} --packageName eslint --packageVersion ~10.14.0
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

packageName=
packageVersion=
binaryNames=
toolName=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${packageName}" ]]; then
  >&2 echo "No package name specified!"
  usage
  exit 1
fi

if [[ -z "${packageVersion}" ]]; then
  >&2 echo "No package version specified!"
  usage
  exit 1
fi

if [[ -z "${binaryNames}" ]]; then
  binaryNames="${packageName##*/}"
fi

if [[ -z "${toolName}" ]]; then
  toolName="${packageName##*/}"
fi

if [[ ! -x "$(command -v npm)" ]]; then
  >&2 echo "npm not found, install Node.js first (cosyses Node.js <version>)"
  exit 1
fi

toolPath="/usr/local/lib/npm-tools/${toolName}"

if [[ -d "${toolPath}" ]]; then
  echo "Removing previous installation in: ${toolPath}"
  rm -rf "${toolPath}"
fi

mkdir -p "${toolPath}"

echo "Installing ${packageName} ${packageVersion} into: ${toolPath}"
echo "{}" > "${toolPath}/package.json"
npm install --prefix "${toolPath}" --no-audit --no-fund --no-update-notifier "${packageName}@${packageVersion}"

IFS=',' read -r -a binaryNameList <<< "${binaryNames}"
for binaryName in "${binaryNameList[@]}"; do
  if [[ ! -e "${toolPath}/node_modules/.bin/${binaryName}" ]]; then
    >&2 echo "Binary not found: ${toolPath}/node_modules/.bin/${binaryName}"
    exit 1
  fi
  echo "Linking /usr/local/bin/${binaryName} to: ${toolPath}/node_modules/.bin/${binaryName}"
  ln -sfn "${toolPath}/node_modules/.bin/${binaryName}" "/usr/local/bin/${binaryName}"
done
