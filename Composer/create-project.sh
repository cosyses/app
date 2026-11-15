#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Creates a project from a Composer package in a directory, or installs its dependencies if the directory already has a
composer.json. The project is created in a temporary directory and copied over, so the directory may exist already
and contain other files (e.g. a mounted volume). PHP and Composer have to be installed (cosyses PHP <version>, cosyses
Composer <version>); credentials for private repositories are added with: cosyses Composer auth.sh

usage: ${scriptFileName} options

OPTIONS:
  --help             Show this message
  --packageName      Name of the Composer package, for example: magento/project-community-edition
  --packageVersion   Version constraint, for example: 2.4.8-p3 or 6.7.*
  --appPath          Directory of the project
  --repositoryUrl    URL of the Composer repository, default: Packagist
  --noScripts        Do not run the scripts of the package (yes/no), default: no
  --removeVcs        Remove the VCS history of the package (yes/no), default: no
  --securityBlocking Refuse package versions with security advisories (yes/no, Composer 2.9+), default: yes
  --requirePackages  Comma separated packages to add, with optional constraint, for example:
                     laravel/framework:~13.0,symfony/twig-bundle
  --requireWithAllDependencies
                     Allow Composer to update dependencies already locked when adding the packages
                     (composer require -W, yes/no), default: no
  --binaries         Comma separated files relative to the project to make executable, for example: bin/console
  --user             System user who owns the project and runs Composer, default: the current user

Example: ${scriptFileName} --packageName shopware/production --packageVersion 6.7.* --appPath /var/www/shop --user www-data
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

packageName=
packageVersion=
appPath=
repositoryUrl=
noScripts=
removeVcs=
securityBlocking=
requirePackages=
requireWithAllDependencies=
binaries=
user=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${appPath}" ]]; then
  >&2 echo "No app path specified!"
  usage
  exit 1
fi

if [[ -z "${noScripts}" ]]; then
  noScripts="no"
fi

if [[ -z "${removeVcs}" ]]; then
  removeVcs="no"
fi

if [[ -z "${securityBlocking}" ]]; then
  securityBlocking="yes"
fi

if [[ -z "${requireWithAllDependencies}" ]]; then
  requireWithAllDependencies="no"
fi

if [[ -z "${user}" ]]; then
  user=$(whoami)
fi

if [[ ! -x "$(command -v composer)" ]]; then
  >&2 echo "Composer not found, install it first (cosyses Composer <version>)"
  exit 1
fi

# Runs Composer as the project user, root needs the permission to run plugins and scripts
runComposer()
{
  if [[ "${user}" != "$(whoami)" ]]; then
    sudo -H -u "${user}" composer "$@"
  else
    COMPOSER_ALLOW_SUPERUSER=1 composer "$@"
  fi
}

if [[ ! -d "${appPath}" ]]; then
  echo "Creating app path: ${appPath}"
  mkdir -p "${appPath}"
  chown "${user}": "${appPath}"
fi

if [[ -f "${appPath}/composer.json" ]]; then
  echo "Installing dependencies of the project in: ${appPath}"
  runComposer install --working-dir "${appPath}" --no-interaction 2>&1
else
  if [[ -z "${packageName}" ]]; then
    >&2 echo "No package name specified!"
    usage
    exit 1
  fi

  tmpPath=$(mktemp -d)
  chown "${user}": "${tmpPath}"
  # The temporary directory has to be empty for create-project
  projectPath="${tmpPath}/project"

  createArguments=( create-project --no-interaction --prefer-dist )
  if [[ -n "${repositoryUrl}" ]]; then
    createArguments+=( "--repository-url=${repositoryUrl}" )
  fi
  if [[ "${noScripts}" == "yes" ]]; then
    createArguments+=( --no-scripts )
  fi
  if [[ "${removeVcs}" == "yes" ]]; then
    createArguments+=( --remove-vcs )
  fi
  requireArguments=( require --working-dir "${projectPath}" --no-interaction )
  if [[ "${securityBlocking}" == "no" ]]; then
    createArguments+=( --no-security-blocking )
    requireArguments+=( --no-security-blocking )
  fi
  if [[ "${requireWithAllDependencies}" == "yes" ]]; then
    requireArguments+=( --with-all-dependencies )
  fi
  if [[ -n "${packageVersion}" ]]; then
    createArguments+=( "${packageName}=${packageVersion}" )
  else
    createArguments+=( "${packageName}" )
  fi
  createArguments+=( "${projectPath}" )

  echo "Creating project from package: ${packageName} ${packageVersion} in: ${projectPath}"
  runComposer "${createArguments[@]}" 2>&1

  if [[ -n "${requirePackages}" ]]; then
    IFS=',' read -r -a requirePackageList <<< "${requirePackages}"
    echo "Adding packages: ${requirePackageList[*]}"
    runComposer "${requireArguments[@]}" "${requirePackageList[@]}" 2>&1
  fi

  echo "Copying project to: ${appPath}"
  # The entries are copied one by one: copying "${projectPath}/." would also set the times of the directory itself, which
  # fails if it belongs to another user (e.g. a mounted volume)
  find "${projectPath}" -mindepth 1 -maxdepth 1 -exec cp -a {} "${appPath}/" \;
  rm -rf "${tmpPath}"
fi

if [[ -n "${binaries}" ]]; then
  IFS=',' read -r -a binaryList <<< "${binaries}"
  for binary in "${binaryList[@]}"; do
    if [[ -f "${appPath}/${binary}" ]]; then
      chmod +x "${appPath}/${binary}"
    fi
  done
fi
