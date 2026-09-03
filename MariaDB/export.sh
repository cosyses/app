#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --databaseHost      Database host, default: 127.0.0.1
  --databasePort      Database port, default: 3306
  --databaseUser      Name of the database user
  --databasePassword  Password of the database user
  --databaseName      Name of the database to import into
  --exportFile        Export file
  --tempDir           Path to temp directory, default: /tmp/mariadb
  --onlyColumns       Flag if only table columns are to be exported (yes/no), default: no
  --onlyRecords       Flag if only records are to be exported (yes/no), default: no
  --removeDatabase    Remove the database after download (yes/no), default: no

Example: ${scriptName} --databaseUser magento --databasePassword magento --databaseName magento --exportFile export.sql
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
exportFile=
tempDir=
onlyColumns=
onlyRecords=
removeDatabase=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${databaseHost}" ]] || [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseUser}" ]]; then
  >&2 echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  >&2 echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  >&2 echo "No database name specified!"
  usage
  exit 1
fi

if [[ -z "${exportFile}" ]]; then
  >&2 echo "No export file specified!"
  usage
  exit 1
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mariadb"
fi

if [[ ! -d "${tempDir}" ]]; then
  rm -rf "${tempDir}"

  echo "Creating temp directory at: ${tempDir}"
  mkdir -p "${tempDir}"
fi

if [[ -z "${onlyColumns}" ]]; then
  onlyColumns="no"
fi

if [[ -z "${onlyRecords}" ]]; then
  onlyRecords="no"
fi

if [[ -z "${removeDatabase}" ]]; then
  removeDatabase="no"
fi

if [[ -f "${exportFile}" ]]; then
  echo "Removing previous export file at: ${exportFile}"
  rm -rf "${exportFile}"
fi

exportPath=$(dirname "$(realpath "${exportFile}")")
exportFileName=$(basename "${exportFile}")

cd "${tempDir}"

if [[ -f export.sql ]]; then
  echo "Removing previous export file at: export.sql"
  rm -rf export.sql
fi

echo "Exporting to file: ${tempDir}/export.sql"
touch export.sql

export MYSQL_PWD="${databasePassword}"

if [[ "${onlyRecords}" == "no" ]]; then
  echo "Exporting all table columns to file: export.sql"
  mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > export.sql
fi

if [[ "${onlyColumns}" == "no" ]]; then
  echo "Exporting all table records to file: export.sql"
  if [[ $(mariadb -B -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" --disable-column-names -e "show events;" >/dev/null 2>&1 && echo "true" || echo "false") == "true" ]]; then
    # shellcheck disable=SC2086
    mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --routines --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> export.sql
  else
    # shellcheck disable=SC2086
    mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --routines --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> export.sql
  fi
fi

cd "${exportPath}"

echo "Moving export.sql to path: ${exportPath}"
mv "${tempDir}/export.sql" .

echo "Preparing export file at: ${exportFile}"
if [[ "${exportFile: -7}" == ".tar.gz" ]]; then
  install-package tar
  tar -czf "${exportFileName}" export.sql
elif [[ "${exportFile: -3}" == ".gz" ]] || [[ "${exportFile: -7}" == ".sql.gz" ]]; then
  install-package gzip
  gzip export.sql
  if [[ "${exportFileName}" != "export.sql.gz" ]]; then
    mv export.sql.gz "${exportFile}"
  fi
elif [[ "${exportFile: -4}" == ".zip" ]]; then
  install-package zip
  zip -q -T -m "${exportFile}" export.sql
elif [[ "${exportFile: -4}" == ".sql" ]]; then
  if [[ "${exportFileName}" != "export.sql" ]]; then
    mv export.sql "${exportFileName}"
  fi
else
  echo "Unsupported file format"
  exit 1
fi

if [[ "${removeDatabase}" == "yes" ]]; then
  echo "Dropping database: ${databaseName}"
  mariadb -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"
fi
