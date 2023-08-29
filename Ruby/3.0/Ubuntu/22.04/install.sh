#!/bin/bash -e

install-package ruby "1:3.0"
install-package ruby-dev "1:3.0"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/ruby.sh"
  cat <<EOF > /usr/local/bin/ruby.sh
#!/bin/bash -e
tail -f /dev/null
EOF
  chmod +x /usr/local/bin/ruby.sh
fi

mkdir -p /opt/install/
crudini --set /opt/install/env.properties ruby version "3.0"
