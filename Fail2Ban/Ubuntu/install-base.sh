#!/bin/bash -e

# Set by the version specific install.sh which sources this script
if [[ -z "${fail2banVersion}" ]]; then
  >&2 echo "No Fail2Ban version set!"
  echo ""
  exit 1
fi

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

Installs Fail2Ban from the packages of the release and writes the defaults of all jails to /etc/fail2ban/jail.local.

usage: ${scriptFileName} options

OPTIONS:
  --help      Show this message
  --banTime   Time a host is banned, default: 26h
  --findTime  Time window in which the failures are counted, default: 32m
  --maxRetry  Number of failures in the time window until a host is banned, default: 4

Example: ${scriptFileName} --banTime 26h --findTime 32m --maxRetry 4
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

banTime=
findTime=
maxRetry=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${banTime}" ]]; then
  banTime="26h"
fi

if [[ -z "${findTime}" ]]; then
  findTime="32m"
fi

if [[ -z "${maxRetry}" ]]; then
  maxRetry="4"
fi

install-package fail2ban "${fail2banVersion}"

echo "Writing configuration to: /etc/fail2ban/jail.local"
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = ${banTime}
findtime = ${findTime}
maxretry = ${maxRetry}
EOF

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/fail2ban.sh"
  cat <<EOF > /usr/local/bin/fail2ban.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Fail2Ban"
  fail2ban-client stop
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Fail2Ban"
mkdir -p /run/fail2ban
# the sshd jail needs its log file, which no syslog daemon creates in a container
touch /var/log/auth.log
fail2ban-client start
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/fail2ban.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-fail2ban.sh"
    cat <<EOF > /usr/local/lib/start/10-fail2ban.sh
#!/usr/bin/env bash
echo "Starting Fail2Ban"
mkdir -p /run/fail2ban
# the sshd jail needs its log file, which no syslog daemon creates in a container
touch /var/log/auth.log
fail2ban-client start
EOF
    chmod +x /usr/local/lib/start/10-fail2ban.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-fail2ban.sh"
    cat <<EOF > /usr/local/lib/stop/10-fail2ban.sh
#!/usr/bin/env bash
echo "Stopping Fail2Ban"
fail2ban-client stop
EOF
    chmod +x /usr/local/lib/stop/10-fail2ban.sh
  fi
else
  echo "Restarting Fail2Ban"
  service fail2ban restart

  echo "Enabling autostart"
  systemctl enable fail2ban
fi
