#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

OPTIONS:
  --help               Show this message
  --user               System user, default: www-data
  --composerUser       Composer user
  --composerPassword   Composer password
  --magentoServerPath  Path to installation, default: magento-server

Example: ${scriptFileName} --composerUser user --composerPassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  usage
  exit 1
fi

if [[ -z "${applicationScriptPath}" ]]; then
  >&2 echo "No application script path exported!"
  echo ""
  usage
  exit 1
fi

user=
composerUser=
composerPassword=
magentoServerPath=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${user}" ]] || [[ "${user}" == "-" ]]; then
  user="www-data"
fi

if [[ -z "${composerUser}" ]] || [[ "${composerUser}" == "-" ]]; then
  >&2 echo "No composer user specified!"
  exit 1
fi

if [[ -z "${composerPassword}" ]] || [[ "${composerPassword}" == "-" ]]; then
  >&2 echo "No composer password specified!"
  exit 1
fi

if [[ -z "${magentoServerPath}" ]] || [[ "${magentoServerPath}" == "-" ]]; then
  magentoServerPath="magento-server"
fi

prepare-user -u "${user}"

sudo -H -u "${user}" bash -c "cd ~; composer config --global --no-interaction http-basic.repo.packagist.com ${composerUser} ${composerPassword}"
sudo -H -u "${user}" bash -c "cd ~; composer create-project --repository-url=https://repo.packagist.com/tofex/ \"tofex/magento-server-project\" --no-interaction --prefer-dist --ansi ${magentoServerPath}"
sudo -H -u "${user}" bash -c "cd ~; ${magentoServerPath}/core/init.sh"

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/magentoserver.sh"
  cat <<EOF > /usr/local/bin/magentoserver.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Magento Server"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Magento Server"
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/magentoserver.sh
fi
