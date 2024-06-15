#!/bin/bash -e

hostName="${1}"
sslCertificate="${2}"
sslKey="${3}"
countryName="${4:-'DE'}"
stateName="${5:-'Thuringia'}"
localityName="${6:-'Jena'}"
organizationName="${7:-'IT'}"
organizationalUnitName="${8:-Development}"

sslCertificatePath=$(dirname "${sslCertificate}")

if [[ -z "${sslCertificatePath}" ]] || { [[ "${sslCertificatePath}" == "." ]] && [[ "${sslCertificate:0:1}" != "." ]]; }; then
  sslCertificatePath="/etc/ssl/certs"
  sslCertificate="${sslCertificatePath}/${sslCertificate}"
fi

sslKeyPath=$(dirname "${sslKey}")

if [[ -z "${sslKeyPath}" ]] || { [[ "${sslKeyPath}" == "." ]] && [[ "${sslKey:0:1}" != "." ]]; }; then
  sslKeyPath="/etc/ssl/private"
  sslKey="${sslKeyPath}/${sslKey}"
fi

if [ ! -f "${sslCertificate}" ] || [ ! -f "${sslKey}" ]; then
  echo "Creating certificate files with key at: ${sslKey} and certificate at: ${sslCertificate}"

  if [[ ! -d "${sslKeyPath}" ]]; then
    echo "Creating directory at: ${sslKeyPath}"
    mkdir -p "${sslKeyPath}"
  fi

  if [[ ! -d "${sslCertificatePath}" ]]; then
    echo "Creating directory at: ${sslCertificatePath}"
    mkdir -p "${sslCertificatePath}"
  fi

  openssl req -nodes -new -x509 -days 3650 -subj "/C=${countryName}/ST=${stateName}/L=${localityName}/O=${organizationName}/OU=${organizationalUnitName}/CN=${hostName}" -keyout "${sslKey}" -out "${sslCertificate}"
else
  echo "Certificate files already exist"
fi
