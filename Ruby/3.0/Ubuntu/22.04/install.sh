#!/bin/bash -e

install-package ruby "1:3.0"
install-package ruby-dev "1:3.0"

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
