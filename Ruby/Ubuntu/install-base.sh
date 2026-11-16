#!/bin/bash -e

# Set by the version specific install.sh which sources this script, the Ruby version of the distribution
if [[ -z "${rubyVersion}" ]]; then
  >&2 echo "No Ruby version specified!"
  echo ""
  exit 1
fi

install-package ruby "1:${rubyVersion}"
install-package ruby-dev "1:${rubyVersion}"

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
