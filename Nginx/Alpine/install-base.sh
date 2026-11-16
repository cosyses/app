#!/bin/bash -e

scriptFileName="${BASH_SOURCE[0]}"
if [[ -L "${scriptFileName}" ]] && [[ -x "$(command -v readlink)" ]]; then
  scriptFileName=$(readlink -f "${scriptFileName}")
fi

usage()
{
cat >&2 << EOF

usage: ${scriptFileName} options

Installs Nginx from the mainline or stable repository of nginx.org, which keep all versions of their current lines.

OPTIONS:
  --help         Show this message
  --httpPort     HTTP port, default: 80
  --sslPort      SSL Port, default: 443
  --sslCertFile  SSL certificate file, default: /etc/ssl/certs/ssl-cert-snakeoil.pem
  --sslKeyFile   SSL key file, default: /etc/ssl/private/ssl-cert-snakeoil.key

Example: ${scriptFileName} --httpPort 80 --sslPort 443
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

# Set by the version specific install.sh which sources this script
if [[ -z "${nginxVersion}" ]]; then
  >&2 echo "No Nginx version specified!"
  echo ""
  exit 1
fi

if [[ "${nginxRepository}" != "mainline" ]] && [[ "${nginxRepository}" != "stable" ]]; then
  >&2 echo "Invalid Nginx repository specified: ${nginxRepository}"
  echo ""
  exit 1
fi

if [[ -z "${applicationName}" ]]; then
  >&2 echo "No application name exported!"
  echo ""
  exit 1
fi

if [[ -z "${applicationVersion}" ]]; then
  >&2 echo "No application version exported!"
  echo ""
  exit 1
fi

httpPort=
sslPort=
sslCertFile=
sslKeyFile=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${httpPort}" ]]; then
  httpPort="80"
fi

if [[ -z "${sslPort}" ]]; then
  sslPort="443"
fi

if [[ -n "${sslCertFile}" ]] && [[ ! -f "${sslCertFile}" ]]; then
  echo "Invalid SSL certificate file specified!"
  exit 1
fi

if [[ -z "${sslCertFile}" ]]; then
  sslCertFile="/etc/ssl/certs/ssl-cert-snakeoil.pem"
fi

if [[ -n "${sslKeyFile}" ]] && [[ ! -f "${sslKeyFile}" ]]; then
  echo "Invalid SSL key file specified!"
  exit 1
fi

if [[ -z "${sslKeyFile}" ]]; then
  sslKeyFile="/etc/ssl/private/ssl-cert-snakeoil.key"
fi

# The repository of another Alpine release can be set by the version specific install.sh (nginx.org builds a line only
# for the Alpine releases that exist while it is maintained), the libraries come from the current release
if [[ -z "${nginxRepositoryRelease}" ]]; then
  nginxRepositoryRelease=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"' | cut -f1-2 -d".")
fi

install-package openssl
add-certificate "default" "${sslCertFile}" "${sslKeyFile}"

if [[ "${nginxRepository}" == "mainline" ]]; then
  nginxRepositoryUrl="https://nginx.org/packages/mainline/alpine/v${nginxRepositoryRelease}/main"
else
  nginxRepositoryUrl="https://nginx.org/packages/alpine/v${nginxRepositoryRelease}/main"
fi
add-apk-repository "${nginxRepositoryUrl}" "https://nginx.org/keys/nginx_signing.rsa.pub"

# Alpine has its own package of the same name (configuration in /etc/nginx/http.d), with a higher package release, so
# the latest version of this line is taken from the nginx.org repository only (apk policy lists the repositories of
# each version below it)
nginxPackageVersion=$(apk policy nginx 2>/dev/null | awk -v repositoryUrl="${nginxRepositoryUrl}" -v baseVersion="${nginxVersion}." '
  /^  [^ ].*:$/ { version = substr($0, 3, length($0) - 3); next }
  /^    / { gsub(/^ +/, ""); if ($0 == repositoryUrl && index(version, baseVersion) == 1) { print version } }
' | sort -rV | head -n 1)
if [[ -z "${nginxPackageVersion}" ]]; then
  >&2 echo "Could not find Nginx ${nginxVersion} in repository: ${nginxRepositoryUrl}"
  exit 1
fi
install-package nginx "${nginxPackageVersion}"

rm -rf /var/log/nginx/*

replace-file-content /etc/nginx/nginx.conf "sendfile        on" "sendfile        off"

usermod -a -G www-data nginx

if [[ -f /.dockerenv ]]; then
  echo "Creating start script at: /usr/local/bin/nginx.sh"
  cat <<EOF > /usr/local/bin/nginx.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping Nginx"
  /usr/sbin/nginx -s quit
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
echo "Starting Nginx"
/usr/sbin/nginx -c /etc/nginx/nginx.conf &
tail -f /dev/null & wait \$!
EOF
  chmod +x /usr/local/bin/nginx.sh

  if [[ -d /usr/local/lib/start/ ]]; then
    echo "Creating start script at: /usr/local/lib/start/10-nginx.sh"
    cat <<EOF > /usr/local/lib/start/10-nginx.sh
#!/usr/bin/env bash
echo "Starting Nginx"
/usr/sbin/nginx -c /etc/nginx/nginx.conf
EOF
    chmod +x /usr/local/lib/start/10-nginx.sh
  fi

  if [[ -d /usr/local/lib/stop/ ]]; then
    echo "Creating stop script at: /usr/local/lib/stop/10-nginx.sh"
    cat <<EOF > /usr/local/lib/stop/10-nginx.sh
#!/usr/bin/env bash
echo "Stopping Nginx"
/usr/sbin/nginx -s quit
EOF
    chmod +x /usr/local/lib/stop/10-nginx.sh
  fi
elif [[ -x "$(command -v rc-service)" ]]; then
  echo "Starting service"
  rc-update add nginx default
  rc-service nginx restart
fi

cosyses \
  --applicationName "${applicationName}" \
  --applicationVersion "${applicationVersion}" \
  --applicationScript default.sh \
  --httpPort "${httpPort}" \
  --sslPort "${sslPort}" \
  --sslCertFile "${sslCertFile}" \
  --sslKeyFile "${sslKeyFile}"
