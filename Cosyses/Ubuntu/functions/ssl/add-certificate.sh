#!/bin/bash -e

hostName="${1}"
sslCertificate="${2}"
sslKey="${3}"

if [ ! -f "${sslCertificate}" ] || [ ! -f "${sslKey}" ]; then
  echo "Creating certificate files with key at: ${sslKey} and certificate at: ${sslCertificate}"

  sslKeyPath=$(basename "${sslKey}")

  if [[ ! -d "${sslKeyPath}" ]]; then
    echo "Creating directory at: ${sslKeyPath}"
    mkdir -p "${sslKeyPath}"
  fi

  sslCertificatePath=$(basename "${sslCertificate}")

  if [[ ! -d "${sslCertificatePath}" ]]; then
    echo "Creating directory at: ${sslCertificatePath}"
    mkdir -p "${sslCertificatePath}"
  fi

  openssl req -nodes -new -x509 -days 3650 -subj "/C=DE/ST=Thuringia/L=Jena/O=Server/OU=Development/CN=${hostName}" -keyout "${sslKey}" -out "${sslCertificate}"
else
  echo "Certificate files already exist"
fi
