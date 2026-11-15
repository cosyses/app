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
  --help         Show this message
  --bindAddress  Bind address, default: 127.0.0.1 or 0.0.0.0 if docker environment
  --port         Port, default: 6379
  --maxMemory    Max memory in MB, default: 2048
  --save         Save (yes/no), default: yes
  --password     Password (optional)
  --allowSync    Allow syncing (yes/no), default: no
  --syncAlias    Sync alias (reqired if allow syncing = no), default: generated
  --psyncAlias   PSync alias (reqired if allow syncing = no), default: generated

Example: ${scriptFileName} --bindAddress 0.0.0.0 --port 6379 --maxMemory 2048
EOF
}

randomString()
{
  local length
  length=${1}
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "${1:-${length}}" | head -n 1
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
maxMemory=
save=
password=
allowSync=
syncAlias=
psyncAlias=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

if [[ -z "${port}" ]]; then
  port="6379"
fi

if [[ -z "${maxMemory}" ]]; then
  maxMemory="2048"
fi

if [[ -z "${save}" ]]; then
  save="yes"
fi

if [[ -z "${allowSync}" ]]; then
  allowSync="no"
fi

if [[ "${allowSync}" == "no" ]]; then
  if [[ -z "${syncAlias}" ]]; then
    syncAlias=$(randomString 32)
  fi

  if [[ -z "${psyncAlias}" ]]; then
    psyncAlias=$(randomString 32)
  fi
fi

echo "Creating Valkey cache configuration at: /etc/valkey/valkey_${port}.conf"
cat <<EOF | sudo tee "/etc/valkey/valkey_${port}.conf" > /dev/null
acllog-max-len 128
activerehashing no
always-show-logo no
aof-load-truncated yes
aof-rewrite-incremental-fsync yes
aof-use-rdb-preamble yes
appendfilename "appendonly.aof"
appendfsync everysec
appendonly no
auto-aof-rewrite-min-size 64mb
auto-aof-rewrite-percentage 100
bind ${bindAddress}
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit pubsub 32mb 8mb 60
client-output-buffer-limit replica 256mb 64mb 60
daemonize yes
databases 16
dbfilename ${port}.rdb
dir /var/lib/valkey/${port}
dynamic-hz yes
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
hll-sparse-max-bytes 3000
hz 10
jemalloc-bg-thread yes
latency-monitor-threshold 0
lazyfree-lazy-expire no
lazyfree-lazy-eviction no
lazyfree-lazy-server-del no
lazyfree-lazy-user-del no
list-compress-depth 0
list-max-ziplist-size -2
logfile /var/log/valkey/${port}.log
loglevel notice
lua-time-limit 5000
maxmemory ${maxMemory}MB
maxmemory-policy allkeys-lru
maxmemory-samples 5
notify-keyspace-events ""
no-appendfsync-on-rewrite no
pidfile /var/run/valkey_${port}.pid
port ${port}
protected-mode no
rdbchecksum yes
rdbcompression yes
rdb-del-sync-files no
rdb-save-incremental-fsync yes
replica-lazy-flush no
replica-priority 100
replica-read-only yes
replica-serve-stale-data yes
repl-disable-tcp-nodelay no
repl-diskless-load disabled
repl-diskless-sync no
repl-diskless-sync-delay 5
set-max-intset-entries 512
slowlog-log-slower-than 10000
slowlog-max-len 128
stop-writes-on-bgsave-error no
stream-node-max-bytes 4096
stream-node-max-entries 100
supervised no
tcp-backlog 511
tcp-keepalive 300
timeout 0
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
EOF

if [[ "${save}" == "yes" ]]; then
  cat <<EOF | sudo tee -a "/etc/valkey/valkey_${port}.conf" > /dev/null
save 900 1
save 300 10
save 60 10000
EOF
fi

if [[ -n "${password}" ]]; then
  cat <<EOF | sudo tee -a "/etc/valkey/valkey_${port}.conf" > /dev/null
protected-mode yes
requirepass ${password}
EOF
else
  cat <<EOF | sudo tee -a "/etc/valkey/valkey_${port}.conf" > /dev/null
protected-mode no
EOF
fi

if [[ "${allowSync}" == "no" ]]; then
  cat <<EOF | sudo tee -a "/etc/valkey/valkey_${port}.conf" > /dev/null
rename-command SYNC ${syncAlias}
rename-command PSYNC ${psyncAlias}
EOF
fi
