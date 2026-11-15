#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Configures OPcache of the PHP version for the CLI, FPM and the Apache module (if installed) in conf.d/99-opcache.ini.
The PHP CLI is installed first if it is missing. FPM and Apache are restarted (reloaded in containers).

usage: ${scriptFileName} options

OPTIONS:
  --help                   Show this message
  --enable                 Enable OPcache (yes/no), default: yes
  --enableCli              Enable OPcache for the CLI (yes/no), default: no
  --memory                 Memory in MB, default: 256
  --internedStringsBuffer  Memory for interned strings in MB, default: 16
  --maxAcceleratedFiles    Maximum number of cached files, default: 65407
  --validateTimestamps     Check files for changes (yes/no), default: yes
  --revalidateFrequency    Seconds between the checks for changes, default: 2
  --maxWastedPercentage    Percentage of wasted memory that triggers a restart, default: 10
  --fileCache              Directory of a second level file cache (optional)

Example: ${scriptFileName} --memory 512 --validateTimestamps no
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  exit 1
fi

enable=
enableCli=
memory=
internedStringsBuffer=
maxAcceleratedFiles=
validateTimestamps=
revalidateFrequency=
maxWastedPercentage=
fileCache=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${enable}" ]]; then
  enable="yes"
fi

if [[ -z "${enableCli}" ]]; then
  enableCli="no"
fi

if [[ -z "${memory}" ]]; then
  memory="256"
fi

if [[ -z "${internedStringsBuffer}" ]]; then
  internedStringsBuffer="16"
fi

if [[ -z "${maxAcceleratedFiles}" ]]; then
  maxAcceleratedFiles="65407"
fi

if [[ -z "${validateTimestamps}" ]]; then
  validateTimestamps="yes"
fi

if [[ -z "${revalidateFrequency}" ]]; then
  revalidateFrequency="2"
fi

if [[ -z "${maxWastedPercentage}" ]]; then
  maxWastedPercentage="10"
fi

yesNoValue()
{
  if [[ "${1}" == "yes" ]] || [[ "${1}" == 1 ]]; then
    echo 1
  else
    echo 0
  fi
}

phpVersion="${applicationVersion}"
if [[ -z "$(command -v "php${phpVersion}")" ]]; then
  cosyses \
    --applicationName "${applicationName}" \
    --applicationVersion "${applicationVersion}" \
    --type cli
fi

if "php${phpVersion}" -m | grep -qx "Zend OPcache"; then
  echo "OPcache already installed"
else
  install-package "php${phpVersion}-opcache"
fi

if [[ -n "${fileCache}" ]]; then
  echo "Creating file cache directory at: ${fileCache}"
  mkdir -p "${fileCache}"
  chown www-data: "${fileCache}"
fi

for sapi in cli fpm apache2; do
  configurationPath="/etc/php/${phpVersion}/${sapi}/conf.d"
  if [[ ! -d "${configurationPath}" ]]; then
    continue
  fi
  configurationFile="${configurationPath}/99-opcache.ini"
  echo "Writing OPcache configuration to: ${configurationFile}"
  cat <<EOF > "${configurationFile}"
; OPcache configuration of Cosyses, overrides the defaults of 10-opcache.ini
opcache.enable=$(yesNoValue "${enable}")
opcache.enable_cli=$(yesNoValue "${enableCli}")
opcache.memory_consumption=${memory}
opcache.interned_strings_buffer=${internedStringsBuffer}
opcache.max_accelerated_files=${maxAcceleratedFiles}
opcache.validate_timestamps=$(yesNoValue "${validateTimestamps}")
opcache.revalidate_freq=${revalidateFrequency}
opcache.max_wasted_percentage=${maxWastedPercentage}
EOF
  if [[ -n "${fileCache}" ]]; then
    echo "opcache.file_cache=${fileCache}" >> "${configurationFile}"
  fi
done

if [[ -f /.dockerenv ]]; then
  fpmPid=$(pgrep -f "php-fpm: master process.*/${phpVersion}/" || true)
  if [[ -n "${fpmPid}" ]]; then
    echo "Reloading PHP FPM"
    kill -USR2 "${fpmPid}"
  fi
  if [[ -d "/etc/php/${phpVersion}/apache2" ]] && pgrep -x apache2 >/dev/null; then
    echo "Reloading Apache"
    apache2ctl graceful
  fi
else
  if [[ -d "/etc/php/${phpVersion}/fpm" ]]; then
    echo "Restarting PHP FPM"
    service "php${phpVersion}-fpm" restart
  fi
  if [[ -d "/etc/php/${phpVersion}/apache2" ]] && [[ -n "$(command -v apache2)" ]]; then
    echo "Restarting Apache"
    service apache2 restart
  fi
fi
