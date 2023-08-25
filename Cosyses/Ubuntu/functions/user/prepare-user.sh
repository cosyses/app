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
  mkdir -p "${userHome}"
  chown "${userName}":"${userGroup}" "${userHome}"
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

if [[ ! -d "${userHome}/.ssh" ]]; then
  echo "Creating directory: ${userHome}/.ssh"
  mkdir -p "${userHome}/.ssh"
  chown "${userName}":"${userGroup}" "${userHome}/.ssh"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome}/.ssh already created"
fi

currentOwner=$(stat -c '%U' "${userHome}/.ssh")
currentGroup=$(stat -c '%G' "${userHome}/.ssh")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${userHome}/.ssh to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${userHome}/.ssh"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome}/.ssh already owned by user: ${userName}:${userGroup}"
fi

if [[ ! -f "${userHome}/.ssh/known_hosts" ]]; then
  echo "Creating file: ${userHome}/.ssh/known_hosts"
  sudo -H -u "${userName}" bash -c "touch ${userHome}/.ssh/known_hosts"
elif [[ "${verbose}" == 1 ]]; then
  echo "File: ${userHome}/.ssh/known_hosts already created"
fi

currentMode=$(stat --format '%a' "${userHome}/.ssh/known_hosts")
if [[ "${currentMode}" != "600" ]]; then
  echo "Changing mode of file: ${userHome}/.ssh/known_hosts to: 0600"
  chmod 0600 "${userHome}/.ssh/known_hosts"
elif [[ "${verbose}" == 1 ]]; then
  echo "Mode of file: ${userHome}/.ssh/known_hosts already changed to: 0600"
fi

if [[ ! -f "${userHome}/.ssh/id_rsa" ]]; then
  echo "Generating SSH key"
  sudo -H -u "${userName}" bash -c "generate-ssh-key"
elif [[ "${verbose}" == 1 ]]; then
  echo "SSH key already generated"
fi

if [[ ! -d "${userHome}/.cache/" ]]; then
  echo "Creating directory: ${userHome}/.cache/"
  mkdir -p "${userHome}/.cache/"
  chown "${userName}":"${userGroup}" "${userHome}/.cache/"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome}/.cache/ already created"
fi

if [[ ! -d "${userHome}/.config/composer/" ]]; then
  echo "Creating directory: ${userHome}/.config/composer/"
  mkdir -p "${userHome}/.config/composer/"
  chown "${userName}":"${userGroup}" "${userHome}/.config/"
  chown "${userName}":"${userGroup}" "${userHome}/.config/composer/"
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome}/.config/composer/ already created"
fi

currentOwner=$(stat -c '%U' "${userHome}")
currentGroup=$(stat -c '%G' "${userHome}")
if [[ "${currentOwner}" != "${userName}" ]] || [[ "${currentGroup}" != "${userGroup}" ]]; then
  echo "Changing owner of directory: ${userHome} to user: ${userName}:${userGroup}"
  chown -hR "${userName}":"${userGroup}" "${userHome}" | cat
elif [[ "${verbose}" == 1 ]]; then
  echo "Directory: ${userHome} already owned by user: ${userName}:${userGroup}"
fi
