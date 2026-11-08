#!/bin/bash -e

applicationVersion=
force=0

declare -Ag prepareParameters
unparsedParameters=( )
while [[ "$#" -gt 0 ]]; do
  parameter="${1}"
  shift
  if [[ "${parameter:0:2}" == "--" ]] || [[ "${parameter}" =~ ^-[[:alpha:]][[:space:]]+ ]] || [[ "${parameter}" =~ ^-\?$ ]]; then
    if [[ "${parameter}" =~ ^--[[:alpha:]]+[[:space:]]+ ]]; then
      parameter="${parameter:2}"
      prepareParametersKey=$(echo "${parameter}" | grep -oP '[[:alpha:]]+(?=\s)' | tr -d "\n")
      prepareParametersValue=$(echo "${parameter:${#prepareParametersKey}}" | xargs)
      # shellcheck disable=SC2034
      prepareParameters["${prepareParametersKey}"]="${prepareParametersValue}"
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
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
      #echo eval "${prepareParametersKey}=\"${prepareParametersValue}\""
      eval "${prepareParametersKey}=\"${prepareParametersValue}\""
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

distribution=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
distributionVersion=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')

if [[ "${distribution}" == "CentOS Linux" ]] || [[ "${distribution}" == "Debian GNU/Linux" ]] || [[ "${distribution}" == "Fedora" ]] || [[ "${distribution}" == "openSUSE Leap" ]] || [[ "${distribution}" == "Red Hat Enterprise Linux" ]] || [[ "${distribution}" == "Ubuntu" ]] || [[ "${distribution}" == "Alpine Linux" ]]; then
  basePath="/usr/local"
  binPath="${basePath}/bin"
  libPath="${basePath}/lib"
  cosysesPath="${libPath}/cosyses"
else
  >&2 echo "Unsupported OS: ${distribution}"
  exit 1
fi

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
  echo "Preparing distribution detection"

  # Alpine has no lsb_release, install.sh reads /etc/os-release there
  if [[ "${distribution}" != "Alpine Linux" ]] && ! [[ -x "$(command -v lsb_release)" ]]; then
    echo "Installing lsb_release"
    if [[ "${distribution}" == "CentOS Linux" ]]; then
      yum makecache
      yum swap -y fakesystemd systemd
      yum clean all
      yum install -y redhat-lsb-core
    elif [[ "${distribution}" == "Debian GNU/Linux" ]]; then
      apt-get update
      DEBIAN_FRONTEND="noninteractive" apt-get install -y lsb-release
    elif [[ "${distribution}" == "Fedora" ]]; then
      dnf makecache
      dnf install -y redhat-lsb
    elif [[ "${distribution}" == "Manjaro Linux" ]]; then
      pacman -Fy
      yes | LANG=C pacman -S lsb-release
    elif [[ "${distribution}" == "openSUSE Leap" ]]; then
      zypper refresh
      zypper install --no-confirm lsb-release
    elif [[ "${distribution}" == "Red Hat Enterprise Linux" ]]; then
      yum makecache
      yum install -y redhat-lsb-core
    elif [[ "${distribution}" == "Ubuntu" ]]; then
      if [[ $(printf '%s\n' "18.04" "${distributionVersion}" | sort -C -V && echo "yes" || echo "no") == "yes" ]]; then
        apt-get update --allow-releaseinfo-change
      else
        apt-get update
      fi
      DEBIAN_FRONTEND="noninteractive" apt-get install -y apt-utils
      DEBIAN_FRONTEND="noninteractive" apt-get install -y lsb-release
    else
      >&2 echo "Unsupported OS: ${distribution}"
      exit 1
    fi
  fi

  echo "Finished preparing distribution detection"

  if [[ -x "$(command -v update-packages)" ]]; then
    echo "Using custom packages update function"
    customUpdate=1
  else
    echo "Using native packages update function"
    customUpdate=0
  fi

  if [[ "${customUpdate}" == 1 ]]; then
    update-packages
  else
    if [[ "${distribution}" == "CentOS Linux" ]] || [[ "${distribution}" == "Red Hat Enterprise Linux" ]]; then
      yum makecache
    elif [[ "${distribution}" == "Debian GNU/Linux" ]]; then
      apt-get update
    elif [[ "${distribution}" == "Fedora" ]]; then
      dnf makecache
    elif [[ "${distribution}" == "Manjaro Linux" ]]; then
      pacman -Fy
    elif [[ "${distribution}" == "openSUSE Leap" ]]; then
      zypper refresh
    elif [[ "${distribution}" == "Ubuntu" ]]; then
      if [[ $(printf '%s\n' "18.04" "${distributionVersion}" | sort -C -V && echo "yes" || echo "no") == "yes" ]]; then
        apt-get update --allow-releaseinfo-change
      else
        apt-get update
      fi
    elif [[ "${distribution}" == "Alpine Linux" ]]; then
      apk update
    else
      >&2 echo "Unsupported OS: ${distribution}"
      exit 1
    fi
  fi

  if [[ -x "$(command -v install-package)" ]]; then
    echo "Using custom install function"
    customInstall=1
  else
    echo "Using native install function"
    customInstall=0
  fi

  if [[ "${distribution}" == "CentOS Linux" ]]; then
    yum install -y epel-release
    sed -i -e "s/#baseurl=/baseurl=/g" /etc/yum.repos.d/epel.repo
    sed -i -e "s/metalink=/#metalink=/g" /etc/yum.repos.d/epel.repo
    yum makecache
    requiredPackages=( curl jq libcurl nss wget unzip )
  elif [[ "${distribution}" == "Debian GNU/Linux" ]] || [[ "${distribution}" == "Fedora" ]] || [[ "${distribution}" == "openSUSE Leap" ]] || [[ "${distribution}" == "Ubuntu" ]]; then
    requiredPackages=( bc curl jq wget unzip )
  elif [[ "${distribution}" == "Alpine Linux" ]]; then
    # Busybox provides grep, sed, find and sort, but without the GNU options the scripts use
    requiredPackages=( bash curl jq wget unzip coreutils findutils grep sed )
  elif [[ "${distribution}" == "Red Hat Enterprise Linux" ]]; then
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    yum makecache
    requiredPackages=( curl jq libcurl nss wget unzip )
  else
    >&2 echo "Unsupported OS: ${distribution}"
    exit 1
  fi

  if [[ "${distribution}" == "Alpine Linux" ]]; then
    echo "Installing packages: ${requiredPackages[*]}"
    apk add --no-interactive "${requiredPackages[@]}" 2>&1
    requiredPackages=( )
  fi

  for requiredPackage in "${requiredPackages[@]}"; do
    if ! [[ -x "$(command -v "${requiredPackage}")" ]]; then
      echo "Installing package: ${requiredPackage}"
      if [[ "${customInstall}" == 1 ]]; then
        install-package "${requiredPackage}"
      else
        if [[ "${distribution}" == "CentOS Linux" ]] || [[ "${distribution}" == "Red Hat Enterprise Linux" ]]; then
          yum install -y "${requiredPackage}" 2>&1
        elif [[ "${distribution}" == "Debian GNU/Linux" ]] || [[ "${distribution}" == "Ubuntu" ]]; then
          DEBIAN_FRONTEND="noninteractive" apt-get install -y "${requiredPackage}" 2>&1
        elif [[ "${distribution}" == "Fedora" ]]; then
          dnf install -y "${requiredPackage}" 2>&1
        elif [[ "${distribution}" == "openSUSE Leap" ]]; then
          zypper install --no-confirm "${requiredPackage}" 2>&1
        else
          >&2 echo "Unsupported OS: ${distribution}"
          exit 1
        fi
      fi
    else
      echo "${requiredPackage} already installed."
    fi
  done

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
