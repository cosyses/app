#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Adds a job to cron as /etc/cron.d/<name> (replaces a job of that name). Cron must be installed.

OPTIONS:
  --help      Show this message
  --name      Name of the job, letters, digits, "-" and "_" only
  --user      User the command runs as, default: root
  --schedule  When it runs (minute hour day month weekday), default: * * * * *
  --command   Command to run
  --output    Where its output goes, default: /dev/null

Example: ${scriptFileName} --name laravel-schedule --user www-data --command "cd /var/www/laravel && php artisan schedule:run"
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

name=
user=
schedule=
command=
output=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${name}" ]]; then
  >&2 echo "No name specified!"
  echo ""
  usage
  exit 1
fi

# cron ignores files in /etc/cron.d whose names contain other characters (a dot, for example)
if [[ ! "${name}" =~ ^[A-Za-z0-9_-]+$ ]]; then
  >&2 echo "Invalid name: ${name} (letters, digits, \"-\" and \"_\" only)"
  echo ""
  exit 1
fi

if [[ -z "${command}" ]]; then
  >&2 echo "No command specified!"
  echo ""
  usage
  exit 1
fi

if [[ -z "${user}" ]]; then
  user="root"
fi

if [[ -z "${schedule}" ]]; then
  schedule="* * * * *"
fi

if [[ -z "${output}" ]]; then
  output="/dev/null"
fi

if [[ ! -d /etc/cron.d ]]; then
  >&2 echo "Cron is not installed!"
  echo ""
  exit 1
fi

echo "Adding cron job: /etc/cron.d/${name}"
cat <<EOF > "/etc/cron.d/${name}"
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
${schedule} ${user} (${command}) >> ${output} 2>&1
EOF
# cron only reads files of root that nobody else may write
chown root:root "/etc/cron.d/${name}"
chmod 0644 "/etc/cron.d/${name}"

# A running cron does not always notice a new file (in containers the directory's change time is not reliable)
if pgrep -x cron > /dev/null; then
  echo "Restarting cron"
  service cron restart
fi
