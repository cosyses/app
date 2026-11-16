#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the cron daemon cronie, which reads the jobs in /etc/cron.d like cron of Debian. In a container it is started
by a start script (/usr/local/lib/start), else as a service. Jobs are added with the script job.sh.

OPTIONS:
  --help  Show this message

Example: ${scriptFileName}
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

install-package cronie
# pgrep and pkill (busybox has them on Alpine)
if [[ ! -x "$(command -v pgrep)" ]]; then
  install-package procps
fi

mkdir -p /etc/cron.d

# The daemon is called crond on Alpine and cron on openSUSE
cronDaemon=$(command -v crond || command -v cron || true)
if [[ -z "${cronDaemon}" ]]; then
  >&2 echo "Could not find the cron daemon of cronie"
  exit 1
fi
cronDaemonName=$(basename "${cronDaemon}")

if [[ -f /.dockerenv ]]; then
  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/20-cron.sh"
    cat <<EOF > /usr/local/lib/start/20-cron.sh
#!/usr/bin/env bash
echo "Starting cron"
pgrep -x ${cronDaemonName} > /dev/null || ${cronDaemon}
EOF
    chmod +x /usr/local/lib/start/20-cron.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/20-cron.sh"
    cat <<EOF > /usr/local/lib/stop/20-cron.sh
#!/usr/bin/env bash
echo "Stopping cron"
pkill -x ${cronDaemonName} && while pgrep -x ${cronDaemonName} > /dev/null; do sleep 1; done
EOF
    chmod +x /usr/local/lib/stop/20-cron.sh
  fi

  if pgrep -x "${cronDaemonName}" > /dev/null; then
    echo "Cron already running"
  else
    echo "Starting cron"
    "${cronDaemon}"
  fi
elif [[ -x "$(command -v systemctl)" ]]; then
  echo "Restarting cron"
  systemctl enable cron
  systemctl restart cron
elif [[ -x "$(command -v rc-service)" ]]; then
  echo "Restarting cron"
  rc-update add crond default
  rc-service crond restart
fi
