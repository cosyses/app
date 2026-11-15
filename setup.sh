#!/bin/bash -e

applicationVersion=
force=0
localPath=

declare -Ag prepareParameters
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter:0:2}" == "--" ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      parameter="${parameter:2}"
      # The value is everything after the key and the blanks behind it, kept as it is
      [[ "${parameter}" =~ ^([[:alpha:]]+)[[:space:]]+(.*)$ ]]
      prepareParametersKey="${BASH_REMATCH[1]}"
      prepareParametersValue="${BASH_REMATCH[2]}"
      prepareParametersValue="${prepareParametersValue%"${prepareParametersValue##*[![:space:]]}"}"
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      # printf -v instead of eval, so that $, backticks and quotes in values are kept as they are
      printf -v "${prepareParametersKey}" '%s' "${prepareParametersValue}"
      continue
    fi
    if [[ "${parameter:0:2}" == "--" ]]; then
      prepareParametersKey="${parameter:2}"
    elif [[ "${parameter}" =~ ^-\?$ ]]; then
      prepareParametersKey="help"
    else
      prepareParametersKey="${parameter:1}"
    fi
    if [[ "$#" -eq 0 ]]; then
      prepareParameters["${prepareParametersKey}"]=1
      #echo eval "${prepareParametersKey}=1"
      eval "${prepareParametersKey}=1"
    else
      prepareParametersValue="${1}"
      if [[ "${prepareParametersValue:0:2}" == "--" ]]; then
        prepareParameters["${prepareParametersKey}"]=1
        #echo eval "${prepareParametersKey}=1"
        eval "${prepareParametersKey}=1"
        continue
      fi
      shift
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      printf -v "${prepareParametersKey}" '%s' "${prepareParametersValue}"
    fi
  else
    unparsedParameters+=("${parameter}")
  fi
done
set -- "${unparsedParameters[@]}"

prepareParametersList=()
for prepareParametersKey in "${!prepareParameters[@]}"; do
  prepareParametersList+=( "--${prepareParametersKey}" )
  prepareParametersValue="${prepareParameters[${prepareParametersKey}]}"
  prepareParametersList+=( "${prepareParametersValue}" )
done
for unparsedParametersKey in "${!unparsedParameters[@]}"; do
  unparsedParametersValue="${unparsedParameters[${unparsedParametersKey}]}"
  prepareParametersList+=( "${unparsedParametersValue}" )
done

distribution=$(awk -F= '/^NAME=/{print $2}' /etc/os-release | tr -d '"')
distributionId=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
distributionVersion=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')

# The supported distributions by their package manager, RHEL compatible ones (AlmaLinux, Rocky, CentOS Stream) included
case "${distributionId}" in
  ubuntu|debian) packageManager="apt" ;;
  fedora|rhel|almalinux|rocky|centos) packageManager="dnf" ;;
  opensuse-leap) packageManager="zypper" ;;
  alpine) packageManager="apk" ;;
  *)
    >&2 echo "Unsupported OS: ${distribution}"
    exit 1
    ;;
esac

basePath="/usr/local"
binPath="${basePath}/bin"
libPath="${basePath}/lib"
cosysesPath="${libPath}/cosyses"

# Installs packages with the native package manager
installNativePackages()
{
  if [[ "${packageManager}" == "apt" ]]; then
    DEBIAN_FRONTEND="noninteractive" apt-get install -y "$@" 2>&1
  elif [[ "${packageManager}" == "dnf" ]]; then
    dnf install -y "$@" 2>&1
  elif [[ "${packageManager}" == "zypper" ]]; then
    zypper --non-interactive install "$@" 2>&1
  elif [[ "${packageManager}" == "apk" ]]; then
    apk add --no-interactive "$@" 2>&1
  fi
}

mkdir -p "${binPath}"
mkdir -p "${libPath}"
mkdir -p "${cosysesPath}"

currentReleasePath="${cosysesPath}/current"

# Ends the setup without changing the installation: an update keeps a working installed release, a new installation fails
abortSetup()
{
  local currentReleaseTarget
  currentReleaseTarget=$(readlink -f "${currentReleasePath}" 2>/dev/null || true)
  if [[ -n "${currentReleaseTarget}" ]] && [[ -f "${currentReleaseTarget}/install.sh" ]]; then
    >&2 echo "Warning: ${1} Keeping installed release: $(basename "${currentReleaseTarget}")"
    exit 0
  fi
  >&2 echo "${1}"
  exit 1
}

# Prints the release data, fails on HTTP errors and on data without a valid release version
determineReleaseData()
{
  local data
  if ! data=$(curl -sfL "${gitReleaseUrl}" 2>/dev/null); then
    return 1
  fi
  if ! [[ $(echo "${data}" | jq -r '.tag_name' 2>/dev/null) =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 1
  fi
  echo "${data}"
}

alreadyInstalled=0

if [[ -n "${applicationVersion}" ]]; then
  releasePath="${cosysesPath}/${applicationVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 0 ]]; then
    echo "Release already installed"
    alreadyInstalled=1
  fi
fi

if [[ "${alreadyInstalled}" == 0 ]]; then
  echo "Preparing package installation"

  if [[ -x "$(command -v update-packages)" ]]; then
    echo "Using custom packages update function"
    update-packages
  else
    echo "Using native packages update function"
    if [[ "${packageManager}" == "apt" ]]; then
      if [[ "${distributionId}" == "ubuntu" ]] && [[ $(printf '%s\n' "18.04" "${distributionVersion}" | sort -C -V && echo "yes" || echo "no") == "yes" ]]; then
        apt-get update --allow-releaseinfo-change
      else
        apt-get update
      fi
    elif [[ "${packageManager}" == "dnf" ]]; then
      dnf makecache
    elif [[ "${packageManager}" == "zypper" ]]; then
      zypper --non-interactive refresh
    elif [[ "${packageManager}" == "apk" ]]; then
      apk update
    fi
  fi

  # Commands needed by this script, install.sh and the helper functions, with the package that provides them. Scripts
  # of Ubuntu and Debian also call lsb_release. Busybox on Alpine provides grep, sed, find and sort, but without the
  # GNU options the scripts use.
  declare -A requiredPackages=( [bc]=bc [curl]=curl [jq]=jq [wget]=wget [unzip]=unzip [find]=findutils )
  if [[ "${packageManager}" == "apt" ]]; then
    requiredPackages[lsb_release]=lsb-release
  elif [[ "${packageManager}" == "apk" ]]; then
    requiredPackages=( [bash]=bash [curl]=curl [jq]=jq [wget]=wget [unzip]=unzip )
  fi

  missingPackages=( )
  for requiredCommand in "${!requiredPackages[@]}"; do
    if ! [[ -x "$(command -v "${requiredCommand}")" ]]; then
      missingPackages+=( "${requiredPackages[${requiredCommand}]}" )
    fi
  done
  # Busybox has its own versions of these commands, so they are always installed on Alpine
  if [[ "${packageManager}" == "apk" ]]; then
    missingPackages+=( coreutils findutils grep sed )
  fi

  if [[ "${#missingPackages[@]}" -gt 0 ]]; then
    echo "Installing packages: ${missingPackages[*]}"
    installNativePackages "${missingPackages[@]}"
  else
    echo "Required packages already installed"
  fi
fi

# A local checkout instead of a release, e.g. to test changes that are not released yet
if [[ -n "${localPath}" ]]; then
  if [[ ! -f "${localPath}/install.sh" ]]; then
    >&2 echo "No Cosyses checkout at: ${localPath}"
    exit 1
  fi
  releasePath=$(cd "${localPath}" && pwd)
  echo "Using local checkout at: ${releasePath}"
fi

if [[ "${alreadyInstalled}" == 0 ]] && [[ -z "${localPath}" ]]; then
  if [[ -n "${applicationVersion}" ]]; then
    gitReleaseUrl="https://api.github.com/repos/cosyses/app/releases/tags/${applicationVersion}"
  else
    gitReleaseUrl="https://api.github.com/repos/cosyses/app/releases/latest"
  fi

  echo "Determining release data"
  releaseData=$(determineReleaseData || true)
  if [[ -z "${releaseData}" ]]; then
    counter=0
    until [[ "${counter}" -gt 20 ]]; do
      ((counter++)) || true
      >&2 echo "Could not determine release data. Waiting three seconds to avoid too many requests timeout."
      sleep 3
      echo "Determining release data (retry #${counter})"
      releaseData=$(determineReleaseData || true)
      if [[ -n "${releaseData}" ]]; then
        break;
      fi
    done
  fi

  if [[ -z "${releaseData}" ]]; then
    abortSetup "Could not determine release data from: ${gitReleaseUrl}"
  fi

  releaseVersion=$(echo "${releaseData}" | jq -r '.tag_name')
  echo "Release version: ${releaseVersion}"

  if [[ ! -d "${cosysesPath}" ]]; then
    echo "Creating base path at: ${cosysesPath}"
    mkdir -p "${cosysesPath}"
  fi

  releasePath="${cosysesPath}/${releaseVersion}"

  if [[ -d "${releasePath}" ]] && [[ "${force}" == 1 ]]; then
    echo "Removing previously installed release"
    rm -rf "${releasePath}"
  fi

  if [[ -d "${releasePath}" ]]; then
    echo "Release already installed"
  else
    releaseZipUrl=$(echo "${releaseData}" | jq -r '.zipball_url')
    if ! [[ "${releaseZipUrl}" =~ ^https?:// ]]; then
      abortSetup "No release archive found for release: ${releaseVersion}"
    fi
    releaseZipPath="${cosysesPath}/${releaseVersion}.zip"
    releaseTempPath="${cosysesPath}/${releaseVersion}.tmp"
    rm -rf "${releaseZipPath}" "${releaseTempPath}"

    echo "Downloading release archive from url: ${releaseZipUrl}"
    counter=0
    until result=$(wget -q -O "${releaseZipPath}" "${releaseZipUrl}" 2>&1); do
      rm -f "${releaseZipPath}"
      if ! [[ "${result}" =~ "ERROR 429" ]] || [[ "${counter}" -ge 20 ]]; then
        abortSetup "Could not download release archive from: ${releaseZipUrl} ${result}"
      fi
      ((counter++)) || true
      echo "Could not download release archive. Waiting three seconds to avoid too many requests timeout"
      sleep 3
      echo "Downloading release archive from url: ${releaseZipUrl} (retry #${counter})"
    done

    # Extract into a temporary directory, so that an incomplete release is never taken for an installed one
    echo "Extracting downloaded release archive"
    if ! unzip -o -q "${releaseZipPath}" -d "${releaseTempPath}"; then
      rm -rf "${releaseZipPath}" "${releaseTempPath}"
      abortSetup "Could not extract release archive downloaded from: ${releaseZipUrl}"
    fi

    echo "Removing downloaded release archive"
    rm -rf "${releaseZipPath}"

    releasePathGitPath=$(find "${releaseTempPath}" -mindepth 1 -maxdepth 1 -type d -name '[^.]?*' -printf %f -quit)
    if [[ -z "${releasePathGitPath}" ]] || [[ ! -f "${releaseTempPath}/${releasePathGitPath}/install.sh" ]]; then
      rm -rf "${releaseTempPath}"
      abortSetup "Release archive downloaded from: ${releaseZipUrl} contains no installation"
    fi

    echo "Found git directory: ${releasePathGitPath}"
    mv "${releaseTempPath}/${releasePathGitPath}" "${releasePath}"
    rm -rf "${releaseTempPath}"
    echo "Release archive extracted to: ${releasePath}"
    cd "${releasePath}"
  fi
fi

if [[ ! -f "${releasePath}/install.sh" ]]; then
  abortSetup "Release at: ${releasePath} is incomplete."
fi

if [[ -L "${currentReleasePath}" ]]; then
  if ! [[ $(readlink -f "${currentReleasePath}") == "${releasePath}" ]]; then
    echo "Unlinking currently installed release"
    rm "${currentReleasePath}"
  fi
fi

if ! [[ -L "${currentReleasePath}" ]]; then
  echo "Linking installed release from: ${releasePath} to: ${currentReleasePath}"
  ln -s "${releasePath}" "${currentReleasePath}"
fi

if [[ ! -L "${binPath}/cosyses" ]]; then
  echo "Linking install script from: ${currentReleasePath}/install.sh to: ${binPath}/cosyses"
  ln -s "${currentReleasePath}/install.sh" "${binPath}/cosyses"
fi

"${binPath}/cosyses" \
  --applicationName "Cosyses" \
  --applicationScript "functions.sh"
