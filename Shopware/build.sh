#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Builds the JavaScript of a Shopware 6 shop with the build scripts of the project (bin/build-js.sh,
bin/build-administration.sh, bin/build-storefront.sh), for example after installing a plugin with own administration or
storefront code. Node.js has to be installed (cosyses Node.js <version>, Shopware 6.7 needs Node.js 20 or newer).

usage: ${scriptFileName} options

OPTIONS:
  --help     Show this message
  --appPath  Directory of the project
  --user     System user who owns the project and runs the build, default: www-data
  --target   What to build: js (administration and storefront), administration or storefront, default: js

Example: ${scriptFileName} --appPath /var/www/shop --target storefront
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
target=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ -z "${target}" ]]; then
  target="js"
fi

case "${target}" in
  js) buildScript="bin/build-js.sh" ;;
  administration) buildScript="bin/build-administration.sh" ;;
  storefront) buildScript="bin/build-storefront.sh" ;;
  *)
    >&2 echo "Invalid target: ${target}, use js, administration or storefront"
    usage
    exit 1
    ;;
esac

if [[ ! -x "$(command -v npm)" ]]; then
  >&2 echo "Node.js not found, install it first (cosyses Node.js <version>)"
  exit 1
fi

if [[ ! -f "${appPath}/${buildScript}" ]]; then
  >&2 echo "Build script not found: ${appPath}/${buildScript}"
  exit 1
fi

cd "${appPath}"

echo "Running: ${buildScript}"
if [[ "${user}" != "$(whoami)" ]]; then
  # npm needs a writable cache, the home directory of system users is often not writable
  userHome=$(getent passwd "${user}" | cut -d: -f6)
  if sudo -u "${user}" test -w "${userHome}"; then
    sudo -H -u "${user}" bash "${buildScript}"
  else
    sudo -H -u "${user}" env npm_config_cache="${appPath}/var/cache/npm" bash "${buildScript}"
  fi
else
  bash "${buildScript}"
fi
