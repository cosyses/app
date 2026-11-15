#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Adds the sample data of Magento (Luma demo products, categories, CMS pages and images) to a Magento 2 project, from the
repository https://github.com/magento/magento2-sample-data of the Magento version (without the patch suffix, e.g. 2.4.8
for 2.4.8-p3). The modules are copied to app/code/Magento and the images to pub/media, they are installed with the
next setup:upgrade (cosyses Magento build.sh).

usage: ${scriptFileName} options

OPTIONS:
  --help            Show this message
  --appPath         Path of the Magento installation, default: /var/www/magento/htdocs
  --user            System user who owns the installation and runs bin/magento, default: www-data
  --magentoVersion  Magento version of the sample data, default: the installed version

Example: ${scriptFileName} --appPath /var/www/magento/htdocs
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

appPath=
user=
magentoVersion=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ ! -f "${appPath}/bin/magento" ]]; then
  >&2 echo "No Magento project found in: ${appPath}"
  exit 1
fi

runAsUser()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" "$@"
  else
    "$@"
  fi
}

if [[ -z "${magentoVersion}" ]]; then
  magentoVersion=$(runAsUser php "${appPath}/bin/magento" --version 2>&1 | awk '{print $NF}')
fi

# The sample data is tagged with the version without patch suffix
sampleDataVersion="${magentoVersion%%-p*}"

if [[ ! -x "$(command -v unzip)" ]]; then
  if [[ "$(id -u)" != 0 ]]; then
    >&2 echo "Unzip not found and cannot be installed as user: $(whoami), install it first as root (install-package unzip)"
    exit 1
  fi
  install-package unzip
fi

tmpPath=$(mktemp -d)
chmod 755 "${tmpPath}"

echo "Downloading sample data from: https://github.com/magento/magento2-sample-data/archive/${sampleDataVersion}.zip"
wget -nv -O "${tmpPath}/sample-data.zip" "https://github.com/magento/magento2-sample-data/archive/${sampleDataVersion}.zip" 2>&1
unzip -q "${tmpPath}/sample-data.zip" -d "${tmpPath}"
chmod -R a+rX "${tmpPath}"

sampleDataPath="${tmpPath}/magento2-sample-data-${sampleDataVersion}"

echo "Copying sample data to: ${appPath}"
runAsUser mkdir -p "${appPath}/app/code/Magento" "${appPath}/dev/tests/integration/testsuite/Magento/SampleData" "${appPath}/dev/tools" "${appPath}/pub/media"
runAsUser cp -R "${sampleDataPath}/app/code/Magento/." "${appPath}/app/code/Magento/"
runAsUser cp -R "${sampleDataPath}/dev/tests/integration/testsuite/Magento/SampleData/." "${appPath}/dev/tests/integration/testsuite/Magento/SampleData/"
runAsUser cp "${sampleDataPath}/dev/tools/build-sample-data.php" "${appPath}/dev/tools/build-sample-data.php"
runAsUser cp -R "${sampleDataPath}/pub/media/." "${appPath}/pub/media/"

rm -rf "${tmpPath}"

echo "Sample data copied, install it with: cosyses Magento build.sh"
