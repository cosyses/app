#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -u  User to prepare
  -s  Allow sudo only with password
  -d  Disallow sudo
  -v  Verbose

Example: ${scriptName} -u username -s
EOF
}

trim()
{
  echo -n "$1" | xargs
}

userName=
sudoWithPassword=0
disallowSudo=0
verbose=0

while getopts hu:sdv? option; do
  case ${option} in
    h) usage; exit 1;;
    u) userName=$(trim "$OPTARG");;
    s) sudoWithPassword=1;;
    d) disallowSudo=1;;
    v) verbose=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${userName}" ]]; then
  echo "No user name specified!"
  exit 1
fi

install-package sudo
install-package coreutils

echo "Preparing user: ${userName}"

userGroup=$(id -gn "${userName}")
userHome=$(grep "${userName}" /etc/passwd | cut -d':' -f6)
userBash=$(grep "${userName}" /etc/passwd | cut -d':' -f7)

if [[ "${userBash}" != "/bin/bash" ]]; then
  echo "Enable bash for user: ${userName}"
  chsh -s /bin/bash "${userName}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Bash for user: ${userName} already enabled"
fi

if [[ ! -d "${userHome}" ]]; then
  echo "Creating user home directory: ${userHome}"
  mkdir -p "${userHome}"
elif [[ "${verbose}" == 1 ]]; then
  echo "User home directory: ${userHome} already exists"
fi

currentOwner=$(stat -c '%U' "${userHome}")
currentGroup=$(stat -c '%G' "${userHome}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${userHome} to user: ${userName}:${userGroup}"
  chown "${userName}":"${userGroup}" "${userHome}" | cat
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome} already owned by user: ${userName}:${userGroup}"
fi

sshDirectory="${userHome}/.ssh"

if [[ ! -d "${sshDirectory}" ]]; then
  echo "Creating directory: ${sshDirectory}"
  mkdir -p "${sshDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${sshDirectory} already created"
fi

currentOwner=$(stat -c '%U' "${sshDirectory}")
currentGroup=$(stat -c '%G' "${sshDirectory}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${sshDirectory} to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${sshDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${sshDirectory} already owned by user: ${userName}:${userGroup}"
fi

knownHostsFile="${sshDirectory}/known_hosts"

if [[ ! -f "${knownHostsFile}" ]]; then
  echo "Creating file: ${knownHostsFile}"
  sudo -H -u "${userName}" bash -c "touch ${knownHostsFile}"
elif [[ "${verbose}" == 1 ]]; then
  echo "File: ${knownHostsFile} already created"
fi

currentMode=$(stat --format '%a' "${knownHostsFile}")
if [[ "${currentMode}" != "600" ]]; then
  echo "Changing mode of file: ${knownHostsFile} to: 0600"
  chmod 0600 "${knownHostsFile}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Mode of file: ${knownHostsFile} already changed to: 0600"
fi

sshIdFile="${sshDirectory}/id_rsa"

if [[ ! -f "${sshIdFile}" ]]; then
  echo "Generating SSH key"
  sudo -H -u "${userName}" bash -c "generate-ssh-key"
elif [[ "${verbose}" == 1 ]]; then
  echo "SSH key already generated"
fi

cacheDirectory="${userHome}/.cache"

if [[ ! -d "${cacheDirectory}" ]]; then
  echo "Creating directory: ${cacheDirectory}"
  mkdir -p "${cacheDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${cacheDirectory} already created"
fi

currentOwner=$(stat -c '%U' "${cacheDirectory}")
currentGroup=$(stat -c '%G' "${cacheDirectory}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${cacheDirectory} to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${cacheDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${cacheDirectory} already owned by user: ${userName}:${userGroup}"
fi

configDirectory="${userHome}/.config"

if [[ ! -d "${configDirectory}" ]]; then
  echo "Creating directory: ${configDirectory}"
  mkdir -p "${configDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${configDirectory} already created"
fi

currentOwner=$(stat -c '%U' "${configDirectory}")
currentGroup=$(stat -c '%G' "${configDirectory}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${configDirectory} to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${configDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${configDirectory} already owned by user: ${userName}:${userGroup}"
fi

composerDirectory="${configDirectory}/composer"

if [[ ! -d "${composerDirectory}" ]]; then
  echo "Creating directory: ${composerDirectory}"
  mkdir -p "${composerDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${composerDirectory} already created"
fi

currentOwner=$(stat -c '%U' "${composerDirectory}")
currentGroup=$(stat -c '%G' "${composerDirectory}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${composerDirectory} to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${composerDirectory}"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${composerDirectory} already owned by user: ${userName}:${userGroup}"
fi

if [[ -f /etc/sudoers.d/ ]]; then
  if [[ "${sudoWithPassword}" == 0 ]] && [[ "${disallowSudo}" == 0 ]]; then
    if [[ ! -f "/etc/sudoers.d/${userName}" ]] || [[ $(grep "${userName} ALL=(ALL) NOPASSWD:ALL" "/etc/sudoers.d/${userName}" | wc -l) -eq 0 ]]; then
      echo "Allow sudo without password for user: ${userName}"
      echo "${userName} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userName}"
      chmod 0440 "/etc/sudoers.d/${userName}"
    elif [[ "${verbose}" == 1 ]]; then
      echo "Sudo without password for user: ${userName} already allowed"
    fi
  elif [[ "${sudoWithPassword}" == 1 ]]; then
    if [[ ! -f "/etc/sudoers.d/${userName}" ]] || [[ $(grep "${userName} ALL=(ALL) ALL" "/etc/sudoers.d/${userName}" | wc -l) -eq 0 ]]; then
      echo "Allow sudo with password for user: ${userName}"
      echo "${userName} ALL=(ALL) ALL" > "/etc/sudoers.d/${userName}"
      chmod 0440 "/etc/sudoers.d/${userName}"
    elif [[ "${verbose}" == 1 ]]; then
      echo "Sudo with password for user: ${userName} already allowed"
    fi
  elif [[ "${disallowSudo}" == 1 ]]; then
    if [[ -f "/etc/sudoers.d/${userName}" ]]; then
      echo "Disallow sudo for user: ${userName}"
      rm -rf "/etc/sudoers.d/${userName}"
    elif [[ "${verbose}" == 1 ]]; then
      echo "Sudo for user: ${userName} already disallowed"
    fi
  fi
fi

if [[ ! -f "${userHome}/.profile" ]]; then
  cat <<EOF | sudo tee "${userHome}/.profile" > /dev/null
# if running bash
if [[ $(which bash | wc -l) -gt 0 ]]; then
  # include .bashrc if it exists
  if [ -f "\${HOME}/.bashrc" ]; then
    . "\${HOME}/.bashrc"
  fi
fi
# set PATH so it includes user's private bin if it exists
if [ -d "\${HOME}/bin" ] ; then
  PATH="\${HOME}/bin:\${PATH}"
fi
# set PATH so it includes user's private bin if it exists
if [ -d "\${HOME}/.local/bin" ] ; then
  PATH="\${HOME}/.local/bin:\${PATH}"
fi
EOF
  chown "${userName}":"${userGroup}" "${userHome}/.profile"
fi
