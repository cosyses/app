#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                  Show this message
  --bindAddress           Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment
  --databasePort          Port, default: 3306
  --serverId              Server Id, default: 1
  --connections           Connections, default: 100
  --innodbBufferPoolSize  InnoDB buffer pool size in GB, default: 4

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

maxMemory=$(cat /proc/meminfo | grep "MemTotal:" | cut -d':' -f2 | xargs | cut -d' ' -f1)
baseMemory=$(bc <<< "$(bc <<< ${innodbBufferPoolSize}+1.5)"*1024*1024 | awk '{print int($1+0.5)}')

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
  sudo service mysql stop 2>&1
fi

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqld.cnf"
cat <<EOF | sudo tee "/etc/mysql/my.cnf" > /dev/null
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqld.cnf"
cat <<EOF | sudo tee "/etc/mysql/mysql.conf.d/mysqld.cnf" > /dev/null
[mysqld]
back_log = 250
bind-address = ${bindAddress}
datadir = /var/lib/mysql
#expire_logs_days = 8
innodb_buffer_pool_size = ${innodbBufferPoolSize}G
innodb_buffer_pool_instances = ${innodbBufferPoolSize}
innodb_file_per_table = OFF
innodb_flush_method = O_DIRECT
innodb_log_buffer_size = 320M
innodb_log_file_size = 512M
innodb_read_io_threads = 8
innodb_write_io_threads = 8
join_buffer_size = 16M
key_buffer_size = 16M
#log_bin = /var/log/mysql/mysql-bin.log
log_error = /var/log/mysql/error.log
log_queries_not_using_indexes = 1
max_allowed_packet = 32M
max_binlog_size = 500M
max_connections = ${connections}
max_heap_table_size = 1024M
myisam-recover-options = BACKUP
myisam_sort_buffer_size = 64M
open_files_limit = 65535
pid-file = /var/run/mysqld/mysqld.pid
port = ${databasePort}
query_cache_limit = 16M
query_cache_size = 128M
query_cache_type = 1
read_buffer_size = 2M
read_rnd_buffer_size = 8M
server-id = ${serverId}
skip-external-locking
skip-name-resolve
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 2M
symbolic-links = 0
table_definition_cache = 4096
table_open_cache = 8000
thread_cache_size = 32
thread_stack = 192K
tmp_table_size = 1024M
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqld_safe.cnf"
cat <<EOF | sudo tee "/etc/mysql/mysql.conf.d/mysqld_safe.cnf" > /dev/null
[mysqld_safe]
nice = 0
socket = /var/run/mysqld/mysqld.sock
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/mysqldump.cnf"
cat <<EOF | sudo tee "/etc/mysql/mysql.conf.d/mysqldump.cnf" > /dev/null
[mysqldump]
max_allowed_packet = 2G
quick
quote-names
EOF

echo "Creating configuration at: /etc/mysql/mysql.conf.d/isamchk.cnf"
cat <<EOF | sudo tee "/etc/mysql/mysql.conf.d/isamchk.cnf" > /dev/null
[isamchk]
key_buffer_size = 16M
EOF

echo "Removing binary logs at: /var/lib/mysql/"
sudo find /var/lib/mysql/ -name ib_logfile* -exec sh -c "echo \"Removing file: {}\"; rm -rf {}" \;

if [[ ! -f /.dockerenv ]]; then
  echo "Starting MySQL"
  sudo service mysql start 2>&1
fi
