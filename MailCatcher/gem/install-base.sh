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
  --help      Show this message
  --smtpIp    IP address of SMTP Server, default: 0.0.0.0
  --smtpPort  Port of SMTP Server, default: 1025
  --httpIp    IP address of HTTP Server, default: 0.0.0.0
  --httpPort  Port of HTTP Server, default: 1080

Example: ${scriptFileName} --smtpPort 1025 --httpPort 1080
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

# Set by the version specific install.sh which sources this script
# Optional: mailcatcherDependencies pins dependencies of old versions (gem:version, separated by spaces)
if [[ -z "${mailcatcherVersion}" ]]; then
  >&2 echo "No MailCatcher version specified!"
  echo ""
  exit 1
fi

smtpIp=
smtpPort=
httpIp=
httpPort=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${smtpIp}" ]]; then
  smtpIp="0.0.0.0"
fi

if [[ -z "${smtpPort}" ]]; then
  smtpPort=1025
fi

if [[ -z "${httpIp}" ]]; then
  httpIp="0.0.0.0"
fi

if [[ -z "${httpPort}" ]]; then
  httpPort=1080
fi

cosyses \
  --applicationName Ruby

if [[ -x "$(command -v apk)" ]]; then
  install-package build-base
  install-package openssl-dev
  install-package sqlite-dev
  install-package lsof
else
  install-package gcc
  install-package gcc-c++
  install-package make
  install-package libopenssl-devel
  install-package sqlite3-devel
  install-package lsof
fi

# Old versions pin their dependencies (gem:version), so that gem does not pick versions for newer Ruby versions. The C
# extensions of eventmachine 1.0 and thin 1.5, which MailCatcher 0.6 depends on, do not compile with GCC 14 and later,
# which treats these warnings as errors.
gemBuildFlags="--with-cflags=-Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion"
for mailcatcherDependency in ${mailcatcherDependencies}; do
  dependencyName="${mailcatcherDependency%%:*}"
  dependencyVersion="${mailcatcherDependency#*:}"
  if [[ "$(get-installed-gem-version "${dependencyName}")" != "${dependencyVersion}" ]]; then
    echo "Installing gem ${dependencyName}=${dependencyVersion}"
    gem install "${dependencyName}" -v "${dependencyVersion}" -- "${gemBuildFlags}"
  fi
done

install-gem mailcatcher "${mailcatcherVersion}"

# openSUSE names the executables of gems with the Ruby version, e.g. mailcatcher.ruby3.4
mailcatcherBinary=$(command -v mailcatcher || find "$(ruby -e 'print Gem.bindir')" -maxdepth 1 -name 'mailcatcher*' | head -n 1)
if [[ -z "${mailcatcherBinary}" ]]; then
  >&2 echo "Could not find the executable of MailCatcher"
  exit 1
fi

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/mailcatcher.sh"
  cat <<EOF > /usr/local/bin/mailcatcher.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MailCatcher"
  lsof -nP -iTCP:${smtpPort} -sTCP:LISTEN | awk 'NR > 1 {print \$2}' | xargs kill -15
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting MailCatcher"
${mailcatcherBinary} \
  --smtp-ip ${smtpIp} \
  --smtp-port ${smtpPort} \
  --http-ip ${httpIp} \
  --http-port ${httpPort} &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/mailcatcher.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-mailcatcher.sh"
    cat <<EOF > /usr/local/lib/start/10-mailcatcher.sh
#!/usr/bin/env bash
echo "Starting MailCatcher"
${mailcatcherBinary} \
  --smtp-ip ${smtpIp} \
  --smtp-port ${smtpPort} \
  --http-ip ${httpIp} \
  --http-port ${httpPort} &
EOF
    chmod +x /usr/local/lib/start/10-mailcatcher.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-mailcatcher.sh"
    cat <<EOF > /usr/local/lib/stop/10-mailcatcher.sh
#!/usr/bin/env bash
echo "Stopping MailCatcher"
lsof -nP -iTCP:${smtpPort} -sTCP:LISTEN | awk 'NR > 1 {print \$2}' | xargs kill -15
EOF
    chmod +x /usr/local/lib/stop/10-mailcatcher.sh
  fi
else
  echo "Starting MailCatcher"
  "${mailcatcherBinary}" --smtp-ip "${smtpIp}" --smtp-port "${smtpPort}" --http-ip "${httpIp}" --http-port "${httpPort}"
fi
