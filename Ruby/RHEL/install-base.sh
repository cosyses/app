#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Ruby with its development files (to build gems with native extensions) from the distribution.

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

# Set by the version specific install.sh which sources this script
if [[ -z "${rubyVersion}" ]]; then
  >&2 echo "No Ruby version specified!"
  echo ""
  exit 1
fi

source "${cosysesPath}/prepare-parameters.sh"

install-package ruby "${rubyVersion}"
install-package ruby-devel "${rubyVersion}"
install-package rubygems
# The compiler flags of Ruby on RHEL and Fedora refer to the files of redhat-rpm-config
install-package redhat-rpm-config
install-package gcc
install-package gcc-c++
install-package make

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/ruby.sh"
  cat <<EOF > /usr/local/bin/ruby.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Ruby"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Ruby"
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/ruby.sh
fi
