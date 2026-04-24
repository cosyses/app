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
  echo "Stopping MariaDB"
  sudo service mysql stop 2>&1
fi

echo "Creating configuration at: /etc/mysql/mariadb.cnf"
cat <<EOF | sudo tee "/etc/mysql/mariadb.cnf" > /dev/null
[client-server]
port = ${databasePort}
socket = /run/mysqld/mysqld.sock
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mariadb.conf.d/
EOF

echo "Creating configuration at: /etc/mysql/mariadb.conf.d/50-server.cnf"
cat <<EOF | sudo tee "/etc/mysql/mariadb.conf.d/50-server.cnf" > /dev/null
[server]

[mysqld]
basedir = /usr
bind-address = ${bindAddress}
bulk_insert_buffer_size = 16M
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
concurrent_insert = 2
connect_timeout = 5
datadir = /var/lib/mysql
default_storage_engine  = InnoDB
#expire_logs_days = 8
general_log = 1
general_log_file = /var/log/mysql/mysql.log
innodb_buffer_pool_size = ${innodbBufferPoolSize}G
innodb_file_per_table = OFF
innodb_flush_method = O_DIRECT
innodb_io_capacity = 400
innodb_log_buffer_size = 320M
innodb_log_file_size = 1G
innodb_open_files = 400
key_buffer_size = 32M
lc-messages-dir = /usr/share/mysql
#log_bin = /var/log/mysql/mariadb-bin.log
#log_bin_index = /var/log/mysql/mariadb-bin.index
log_error = /var/log/mysql/error.log
log-queries-not-using-indexes
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 10
max_allowed_packet = 32M
max_binlog_size = 500M
max_connections = ${connections}
max_heap_table_size = 1024M
min_examined_row_limit = 1000
myisam_recover_options = BACKUP
myisam_sort_buffer_size = 512M
optimizer_switch = 'extended_keys=on'
pid-file = /var/run/mysqld/mysqld.pid
port = ${databasePort}
query_cache_limit = 16M
query_cache_size = 64M
query_cache_type = 1
read_buffer_size = 8M
read_rnd_buffer_size = 8M
server-id = ${serverId}
slow_query_log_file = /var/log/mysql/mariadb-slow.log
skip_external_locking
skip_name_resolve
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 2M
table_open_cache = 400
thread_cache_size = 32
thread_cache_size = 8
thread_stack = 192K
tmpdir = /tmp
tmp_table_size = 1024M
user = mysql
wait_timeout = 600

[embedded]

[mariadb]

[mariadb-10.6]
EOF

echo "Creating configuration at: /etc/mysql/mariadb.conf.d/50-mysql-clients.cnf"
cat <<EOF | sudo tee "/etc/mysql/mariadb.conf.d/50-mysql-clients.cnf" > /dev/null
[mysql]

[mysql_upgrade]

[mysqladmin]

[mysqlbinlog]

[mysqlcheck]

[mysqldump]
max_allowed_packet = 2G
quick
quote-names

[mysqlimport]

[mysqlshow]

[mysqlslap]
EOF

echo "Removing binary logs at: /var/lib/mysql/"
sudo find /var/lib/mysql/ -name ib_logfile* -exec sh -c "echo \"Removing file: {}\"; rm -rf {}" \;

if [[ ! -f /.dockerenv ]]; then
  echo "Starting MariaDB"
  sudo service mysql start 2>&1
fi
