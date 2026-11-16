#!/bin/bash -e

# Adds a repository as /etc/yum.repos.d/<name>.repo (several key URLs separated by spaces), e.g.
# add-dnf-repository nginx "https://nginx.org/packages/rhel/9/\$basearch/" https://nginx.org/keys/nginx_signing.key module_hotfixes=1
repositoryName="${1}"
baseUrl="${2}"
keyUrl="${3}"
shift 3 || shift $#

if [[ -z "${repositoryName}" ]] || [[ -z "${baseUrl}" ]]; then
  >&2 echo "usage: add-dnf-repository <name> <baseUrl> [<keyUrl>] [<option>=<value> ...]"
  exit 1
fi

repositoryFile="/etc/yum.repos.d/${repositoryName}.repo"

repositoryContent="[${repositoryName}]
name=${repositoryName}
baseurl=${baseUrl}
enabled=1"
if [[ -n "${keyUrl}" ]]; then
  repositoryContent+="
gpgcheck=1
gpgkey=${keyUrl}"
else
  repositoryContent+="
gpgcheck=0"
fi
for option in "$@"; do
  repositoryContent+="
${option}"
done

if [[ -f "${repositoryFile}" ]] && [[ "$(cat "${repositoryFile}")" == "${repositoryContent}" ]]; then
  echo "Repository ${repositoryName} already installed"
  exit 0
fi

echo "Installing repository: ${repositoryName} from: ${baseUrl}"
echo "${repositoryContent}" > "${repositoryFile}"

# Several keys are separated by spaces, like in the repository file
read -r -a keyUrls <<< "${keyUrl}"
for repositoryKeyUrl in "${keyUrls[@]}"; do
  echo "Importing repository key from: ${repositoryKeyUrl}"
  rpm --import "${repositoryKeyUrl}"
done

dnf -q makecache --repo "${repositoryName}" 2>&1
