#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Removes the generated static content of a Magento 2 shop (preprocessed views, deployed static files, merged CSS and
JavaScript), so that it is generated again, e.g. after changing LESS or JavaScript files in developer mode.

usage: ${scriptFileName} options

OPTIONS:
  --help     Show this message
  --appPath  Path of the Magento installation, default: /var/www/magento/htdocs
  --user     System user who owns the installation, default: www-data

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
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  appPath="/var/www/magento/htdocs"
fi

if [[ -z "${user}" ]]; then
  user="www-data"
fi

if [[ ! -d "${appPath}" ]]; then
  >&2 echo "App path not found: ${appPath}"
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

cd "${appPath}"

# Directories whose content is removed
contentDirectories=(
  var/view_preprocessed
  pub/media/css
  pub/media/css_secure
  pub/media/js
  pub/media/tmp
  pub/static/_cache
  pub/static/adminhtml
  pub/static/frontend
)

for contentDirectory in "${contentDirectories[@]}"; do
  if [[ -d "${contentDirectory}" ]] && [[ -n "$(ls -A "${contentDirectory}")" ]]; then
    echo "Removing content of: ${appPath}/${contentDirectory}"
    runAsUser find "${contentDirectory}" -mindepth 1 -delete
  fi
done

for contentFile in pub/static/deployed_version.txt pub/static/files_hash.txt; do
  if [[ -f "${contentFile}" ]]; then
    echo "Removing file: ${appPath}/${contentFile}"
    runAsUser rm -f "${contentFile}"
  fi
done
