#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Merges the composer.json of a module or package into the composer.json of a project, so that the project can be
installed with the module (for example to test a module in a shop): auth.json, repositories (also from a
repositories.json next to the composer.json of the module), replace, disable-tls, secure-http, allow-plugins,
require, patches (cweagans/composer-patches) and the post-install-cmd and post-update-cmd scripts.

The original auth.json, composer.json and composer.lock of the project are stored as auth.org.json,
composer.org.json and composer.org.lock. If these files exist, they are restored (and installed) first, so a merge
can be repeated. PHP, Composer and jq have to be installed.

usage: ${scriptFileName} options

OPTIONS:
  --help                 Show this message
  --modulePath           Path of the module with the composer.json (and optional auth.json and repositories.json)
  --projectPath          Path of the project with the composer.json to merge into
  --allowPlugins         Comma separated plugins to allow in the project (Composer 2.2 and later), for example:
                         magento/magento-composer-installer,magento/inventory-composer-installer
  --excludePackages      Comma separated patterns of required packages of the module that are not required in the
                         project, for example: php,magento/product-community-edition,magento/framework,
                         default: php
  --excludeRepositories  Comma separated patterns of repository urls of the module that are not added to the
                         project, for example: *repo.magento.com*

Example: ${scriptFileName} --modulePath /var/www/module --projectPath /var/www/magento/htdocs --allowPlugins magento/magento-composer-installer --excludePackages "php,magento/*" --excludeRepositories "*repo.magento.com*"
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

modulePath=
projectPath=
allowPlugins=
excludePackages=
excludeRepositories=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${modulePath}" ]]; then
  >&2 echo "No module path specified!"
  usage
  exit 1
fi

if [[ -z "${projectPath}" ]]; then
  >&2 echo "No project path specified!"
  usage
  exit 1
fi

if [[ -z "${excludePackages}" ]]; then
  excludePackages="php"
fi

moduleAuthFile="${modulePath}/auth.json"
moduleComposerFile="${modulePath}/composer.json"
moduleRepositoriesFile="${modulePath}/repositories.json"
projectAuthFile="${projectPath}/auth.json"
projectComposerFile="${projectPath}/composer.json"
projectLockFile="${projectPath}/composer.lock"
projectAuthOrgFile="${projectPath}/auth.org.json"
projectComposerOrgFile="${projectPath}/composer.org.json"
projectLockOrgFile="${projectPath}/composer.org.lock"

if [[ ! -f "${moduleComposerFile}" ]]; then
  >&2 echo "No composer.json found in module path: ${modulePath}"
  exit 1
fi

if [[ ! -f "${projectComposerFile}" ]]; then
  >&2 echo "No composer.json found in project path: ${projectPath}"
  exit 1
fi

if [[ ! -x "$(command -v composer)" ]]; then
  >&2 echo "Composer not found, install it first (cosyses Composer <version>)"
  exit 1
fi

if [[ ! -x "$(command -v jq)" ]]; then
  install-package jq
fi

export COMPOSER_MEMORY_LIMIT=-1

runComposer()
{
  composer --working-dir "${projectPath}" --no-interaction --ansi "$@" 2>&1
}

# Applies a jq filter to a file, keeps owner and permissions of the file
updateJsonFile()
{
  local jsonFile="${1}"
  shift
  local tempFile
  tempFile=$(mktemp)
  jq "$@" "${jsonFile}" > "${tempFile}"
  cat "${tempFile}" > "${jsonFile}"
  rm -f "${tempFile}"
}

matchesPattern()
{
  local value="${1}"
  local patternList="${2}"
  local pattern
  local patterns
  IFS=',' read -r -a patterns <<< "${patternList}"
  for pattern in "${patterns[@]}"; do
    # shellcheck disable=SC2053
    if [[ -n "${pattern}" ]] && [[ "${value}" == ${pattern} ]]; then
      return 0
    fi
  done
  return 1
}

composerVersion=$(composer --version 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)
echo "Composer version: ${composerVersion}"

pluginSupport=0
if [[ $(printf '%s\n%s\n' "2.2.0" "${composerVersion}" | sort -V | head -n 1) == "2.2.0" ]]; then
  pluginSupport=1
fi

if [[ ! -f "${projectLockFile}" ]]; then
  echo "Installing project to create: ${projectLockFile}"
  runComposer install
fi

restore=0

if [[ -f "${projectAuthOrgFile}" ]]; then
  echo "Restoring: ${projectAuthFile}"
  cp "${projectAuthOrgFile}" "${projectAuthFile}"
  restore=1
elif [[ -f "${projectComposerOrgFile}" ]] && [[ -f "${projectAuthFile}" ]]; then
  # the project had no auth.json before the previous merge
  echo "Removing merged: ${projectAuthFile}"
  rm -f "${projectAuthFile}"
fi

if [[ -f "${projectComposerOrgFile}" ]]; then
  echo "Restoring: ${projectComposerFile}"
  cp "${projectComposerOrgFile}" "${projectComposerFile}"
  restore=1
fi

if [[ -f "${projectLockOrgFile}" ]]; then
  echo "Restoring: ${projectLockFile}"
  cp "${projectLockOrgFile}" "${projectLockFile}"
  restore=1
fi

if [[ "${restore}" == 1 ]]; then
  echo "Installing restored project"
  runComposer install
else
  echo "No stored files to restore"
fi

if [[ -f "${projectAuthFile}" ]]; then
  echo "Storing: ${projectAuthOrgFile}"
  cp "${projectAuthFile}" "${projectAuthOrgFile}"
fi

echo "Storing: ${projectComposerOrgFile}"
cp "${projectComposerFile}" "${projectComposerOrgFile}"

echo "Storing: ${projectLockOrgFile}"
cp "${projectLockFile}" "${projectLockOrgFile}"

composerInstall=0

if [[ "${pluginSupport}" == 1 ]] && [[ -n "${allowPlugins}" ]]; then
  IFS=',' read -r -a allowPluginList <<< "${allowPlugins}"
  for allowPlugin in "${allowPluginList[@]}"; do
    echo "Allowing plugin: ${allowPlugin}"
    runComposer config --no-plugins "allow-plugins.${allowPlugin}" true
  done
fi

if [[ -f "${moduleAuthFile}" ]]; then
  if [[ ! -f "${projectAuthFile}" ]]; then
    echo "{}" > "${projectAuthFile}"
  fi
  mapfile -t authHostList < <(jq -r 'to_entries | .[] | select(.value | type == "object") | .key as $type | .value | keys | .[] | "\($type): \(.)"' "${moduleAuthFile}")
  for authHost in "${authHostList[@]}"; do
    echo "Adding authentication: ${authHost}"
  done
  updateJsonFile "${projectAuthFile}" --slurpfile module "${moduleAuthFile}" '. * $module[0]'
else
  echo "No authentication to add"
fi

mapfile -t replaceList < <(jq -r '(.replace // {}) | to_entries | .[] | "\(.key): \(.value)"' "${moduleComposerFile}")
if [[ "${#replaceList[@]}" -gt 0 ]]; then
  for replace in "${replaceList[@]}"; do
    echo "Adding replacement of package: ${replace}"
  done
  updateJsonFile "${projectComposerFile}" --slurpfile module "${moduleComposerFile}" '.replace = ((.replace // {}) + $module[0].replace)'
else
  echo "No package replacements to add"
fi

repositoryFiles=()
if [[ -f "${moduleRepositoriesFile}" ]]; then
  repositoryFiles+=( "${moduleRepositoriesFile}" )
fi
repositoryFiles+=( "${moduleComposerFile}" )

repositoryCount=0
for repositoryFile in "${repositoryFiles[@]}"; do
  # one repository per line: name, url (- if none) and the repository as JSON (object or false), separated by tabs
  mapfile -t repositoryList < <(jq -r '
    (.repositories // {})
    | if type == "array" then to_entries | map({key: (.value.name // (.value.url // "repository" | gsub("[^A-Za-z0-9]+"; "-") | gsub("^-|-$"; ""))), value: .value}) else to_entries end
    | .[]
    | [.key, (if (.value | type) == "object" then (.value.url // "-") else "-" end), (.value | if type == "object" then del(.name) else . end | tojson)]
    | @tsv' "${repositoryFile}")
  for repository in "${repositoryList[@]}"; do
    IFS=$'\t' read -r repositoryName repositoryUrl repositoryJson <<< "${repository}"
    if [[ "${repositoryUrl}" == "-" ]]; then
      repositoryUrl=
    fi
    if [[ -n "${repositoryUrl}" ]] && matchesPattern "${repositoryUrl}" "${excludeRepositories}"; then
      echo "Excluding repository with name: ${repositoryName} and url: ${repositoryUrl}"
      continue
    fi
    echo "Adding repository with name: ${repositoryName} and url: ${repositoryUrl}"
    runComposer config --no-plugins "repositories.${repositoryName}" "${repositoryJson}"
    repositoryCount=$((repositoryCount + 1))
  done
done
if [[ "${repositoryCount}" == 0 ]]; then
  echo "No repositories to add"
fi

disableTls=$(jq -r '.config["disable-tls"] // empty' "${moduleComposerFile}")
if [[ -n "${disableTls}" ]]; then
  echo "Setting disable-tls to: ${disableTls}"
  runComposer config --no-plugins disable-tls "${disableTls}"
fi

secureHttp=$(jq -r '.config["secure-http"] // empty' "${moduleComposerFile}")
if [[ -n "${secureHttp}" ]]; then
  echo "Setting secure-http to: ${secureHttp}"
  runComposer config --no-plugins secure-http "${secureHttp}"
fi

if [[ "${pluginSupport}" == 1 ]]; then
  mapfile -t pluginList < <(jq -r '(.config["allow-plugins"] // {}) | if type == "object" then to_entries | .[] | "\(.key)\t\(.value)" else empty end' "${moduleComposerFile}")
  if [[ "${#pluginList[@]}" -gt 0 ]]; then
    for plugin in "${pluginList[@]}"; do
      IFS=$'\t' read -r pluginName pluginStatus <<< "${plugin}"
      echo "Setting plugin with name: ${pluginName} to status: ${pluginStatus}"
      runComposer config --no-plugins "allow-plugins.${pluginName}" "${pluginStatus}"
    done
    composerInstall=1
  else
    echo "No plugins configuration to add"
  fi
else
  echo "No plugin handling required"
fi

# one package per line, so that constraints with spaces ("^1.0 || ^2.0") stay one argument
mapfile -t requireList < <(jq -r '(.require // {}) | to_entries | .[] | "\(.key)\t\(.value)"' "${moduleComposerFile}")
packageList=()
for require in "${requireList[@]}"; do
  IFS=$'\t' read -r packageName packageVersion <<< "${require}"
  if matchesPattern "${packageName}" "${excludePackages}"; then
    echo "Excluding required package: ${packageName}"
  else
    packageList+=( "${packageName}:${packageVersion}" )
  fi
done
if [[ "${#packageList[@]}" -gt 0 ]]; then
  echo "Requiring packages: ${packageList[*]}"
  runComposer require --prefer-dist "${packageList[@]}"
else
  echo "No packages to require"
fi

mapfile -t patchList < <(jq -r '(.extra.patches // {}) | to_entries | .[] | .key as $package | .value | to_entries | .[] | "\($package): \(.key)"' "${moduleComposerFile}")
if [[ "${#patchList[@]}" -gt 0 ]]; then
  for patch in "${patchList[@]}"; do
    echo "Adding patch: ${patch}"
  done
  updateJsonFile "${projectComposerFile}" --slurpfile module "${moduleComposerFile}" '.extra.patches = ((.extra.patches // {}) * $module[0].extra.patches)'
  composerInstall=1
else
  echo "No patches to add"
fi

for scriptEvent in post-install-cmd post-update-cmd; do
  mapfile -t scriptCommandList < <(jq -r --arg event "${scriptEvent}" '(.scripts[$event] // []) | if type == "array" then .[] else . end' "${moduleComposerFile}")
  if [[ "${#scriptCommandList[@]}" -gt 0 ]]; then
    for scriptCommand in "${scriptCommandList[@]}"; do
      echo "Adding ${scriptEvent} script: ${scriptCommand}"
    done
    updateJsonFile "${projectComposerFile}" --slurpfile module "${moduleComposerFile}" --arg event "${scriptEvent}" '
      def asArray: if . == null then [] elif type == "array" then . else [.] end;
      .scripts[$event] = ((.scripts[$event] | asArray) + ($module[0].scripts[$event] | asArray) | reduce .[] as $command ([]; if index([$command]) then . else . + [$command] end))'
    if [[ "${scriptEvent}" == "post-install-cmd" ]]; then
      composerInstall=1
    fi
  else
    echo "No ${scriptEvent} scripts to add"
  fi
done

# replace and patches change the hash of composer.json, --no-install needs Composer 2.1 or later
if [[ $(printf '%s\n%s\n' "2.1.0" "${composerVersion}" | sort -V | head -n 1) == "2.1.0" ]]; then
  echo "Updating hash of: ${projectLockFile}"
  runComposer update --lock --no-install --no-scripts
fi

if [[ "${composerInstall}" == 1 ]]; then
  echo "Installing project"
  runComposer install
fi
