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

install-package cron 3.0

if [[ -f /.dockerenv ]]; then
  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/20-cron.sh"
    cat <<EOF > /usr/local/lib/start/20-cron.sh
#!/usr/bin/env bash
echo "Starting cron"
service cron start
EOF
    chmod +x /usr/local/lib/start/20-cron.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/20-cron.sh"
    cat <<EOF > /usr/local/lib/stop/20-cron.sh
#!/usr/bin/env bash
echo "Stopping cron"
service cron stop
EOF
    chmod +x /usr/local/lib/stop/20-cron.sh
  fi

  echo "Starting cron"
  service cron start
else
  echo "Restarting cron"
  service cron restart
fi
