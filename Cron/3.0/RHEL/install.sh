#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs the cron daemon. In a container it is started by a start script (/usr/local/lib/start), else as a service.
Jobs are added with the script job.sh.

RHEL and Fedora have no Vixie cron 3.0 (the cron of Debian and Ubuntu), their cron daemon is cronie, a fork of it,
which reads the jobs in /etc/cron.d the same way.

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

if [[ -f /.dockerenv ]]; then
  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/20-cron.sh"
    cat <<EOF > /usr/local/lib/start/20-cron.sh
#!/usr/bin/env bash
echo "Starting cron"
if ! kill -0 "\$(cat /run/crond.pid 2>/dev/null)" 2>/dev/null; then
  /usr/sbin/crond
fi
EOF
    chmod +x /usr/local/lib/start/20-cron.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/20-cron.sh"
    cat <<EOF > /usr/local/lib/stop/20-cron.sh
#!/usr/bin/env bash
echo "Stopping cron"
cronPid=\$(cat /run/crond.pid 2>/dev/null)
if [[ -n "\${cronPid}" ]] && kill "\${cronPid}" 2>/dev/null; then
  while kill -0 "\${cronPid}" 2>/dev/null; do sleep 1; done
fi
EOF
    chmod +x /usr/local/lib/stop/20-cron.sh
  fi

  echo "Starting cron"
  if ! kill -0 "$(cat /run/crond.pid 2>/dev/null)" 2>/dev/null; then
    /usr/sbin/crond
  fi
else
  echo "Restarting cron"
  systemctl enable crond
  systemctl restart crond
fi
