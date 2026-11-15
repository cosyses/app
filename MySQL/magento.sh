#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

Writes the server configuration of MySQL 8.0 and later (MySQL 5.7 has its own script).

OPTIONS:
  --help                  Show this message
  --bindAddress           Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment
  --databasePort          Port, default: 3306
  --serverId              Server Id, default: 1
  --connections           Connections, default: 100
  --innodbBufferPoolSize  InnoDB buffer pool size in GB, default: 4
  --innodbFilePerTable    Use a file per table (yes/no), default: no
  --lowerCaseTableNames   Store table names in lower case (yes/no), default: no
                          Must match the setting the data directory was initialized with, or MySQL does not start

Example: ${scriptName} --bindAddress 0.0.0.0 --databasePort 3306 --serverId 1 --connections 100 --innodbBufferPoolSize 4
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
databasePort=
serverId=
connections=
innodbBufferPoolSize=
innodbFilePerTable=
lowerCaseTableNames=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${serverId}" ]]; then
  serverId="1"
fi

if [[ -z "${connections}" ]]; then
  connections="100"
fi

if [[ -z "${innodbBufferPoolSize}" ]]; then
  innodbBufferPoolSize="4"
fi

if [[ -z "${innodbFilePerTable}" ]]; then
  innodbFilePerTable="no"
fi

if [[ "${innodbFilePerTable}" == "yes" ]]; then
  innodbFilePerTableValue="ON"
else
  innodbFilePerTableValue="OFF"
fi

if [[ -z "${lowerCaseTableNames}" ]]; then
  lowerCaseTableNames="no"
fi

if [[ "${lowerCaseTableNames}" == "yes" ]]; then
  lowerCaseTableNamesValue=1
else
  lowerCaseTableNamesValue=0
fi

maxMemory=$(grep "MemTotal:" /proc/meminfo | cut -d':' -f2 | xargs | cut -d' ' -f1)
baseMemory=$(bc <<< "(${innodbBufferPoolSize}+1.5)*1024*1024" | awk '{print int($1+0.5)}')

connectionMemory=$((maxMemory - baseMemory))

if [[ "${connectionMemory}" -lt 0 ]]; then
  echo "Not enough memory to set InnoDB buffer pool size to ${innodbBufferPoolSize} GB"
  exit 1
fi

threadMemory=$((connections * 64 * 1024))

remainingMemory=$((connectionMemory - threadMemory))

if [[ "${remainingMemory}" -lt 0 ]]; then
  echo "Not enough memory to use ${connections} connections"
  exit 1
fi

if [[ ! -f /.dockerenv ]]; then
  echo "Stopping MySQL"
  service mysql stop 2>&1
fi

echo "Creating configuration at: /etc/mysql/my.cnf"
cat <<EOF > /etc/mysql/my.cnf
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
EOF

# MySQL 8.0 removed the query cache and symbolic-links, the redo log size is set with innodb_redo_log_capacity since 8.0.30
echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqld.cnf"
cat <<EOF > /etc/mysql/mysql.conf.d/mysqld.cnf
[mysqld]
back_log = 250
bind-address = ${bindAddress}
datadir = /var/lib/mysql
innodb_buffer_pool_size = ${innodbBufferPoolSize}G
innodb_buffer_pool_instances = ${innodbBufferPoolSize}
innodb_file_per_table = ${innodbFilePerTableValue}
innodb_flush_method = O_DIRECT
innodb_log_buffer_size = 320M
innodb_redo_log_capacity = 1G
innodb_read_io_threads = 8
innodb_write_io_threads = 8
join_buffer_size = 16M
key_buffer_size = 16M
log_error = /var/log/mysql/error.log
log_queries_not_using_indexes = 1
lower_case_table_names = ${lowerCaseTableNamesValue}
max_allowed_packet = 32M
max_binlog_size = 500M
max_connections = ${connections}
max_heap_table_size = 1024M
myisam-recover-options = BACKUP
myisam_sort_buffer_size = 64M
open_files_limit = 65535
pid-file = /var/run/mysqld/mysqld.pid
port = ${databasePort}
read_buffer_size = 2M
read_rnd_buffer_size = 8M
server-id = ${serverId}
skip-external-locking
skip-name-resolve
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 2M
table_definition_cache = 4096
table_open_cache = 8000
thread_cache_size = 32
tmp_table_size = 1024M
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqld_safe.cnf"
cat <<EOF > /etc/mysql/mysql.conf.d/mysqld_safe.cnf
[mysqld_safe]
nice = 0
socket = /var/run/mysqld/mysqld.sock
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqldump.cnf"
cat <<EOF > /etc/mysql/mysql.conf.d/mysqldump.cnf
[mysqldump]
max_allowed_packet = 2G
quick
quote-names
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/isamchk.cnf"
cat <<EOF > /etc/mysql/mysql.conf.d/isamchk.cnf
[isamchk]
key_buffer_size = 16M
EOF

if [[ ! -f /.dockerenv ]]; then
  echo "Starting MySQL"
  service mysql start 2>&1
fi
