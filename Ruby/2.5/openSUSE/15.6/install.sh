#!/bin/bash -e

install-package ruby2.5 2.5
install-package ruby2.5-devel 2.5
# The packages without version link ruby, gem, ... to this version
install-package ruby 2.5
install-package ruby-devel 2.5

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
