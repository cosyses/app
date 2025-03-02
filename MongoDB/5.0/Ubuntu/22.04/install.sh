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
  --help           Show this message
  --bindAddress    Bind address, default: 127.0.0.1
  --port           Server port, default: 27017
  --adminUserName  Name of admin user, default: admin
  --adminPassword  Password of admin user, default: <generated>

Example: ${scriptFileName} --adminPassword secret
EOF
}

if [[ -z "${cosysesPath}" ]]; then
  >&2 echo "No cosyses path exported!"
  echo ""
  exit 1
fi

bindAddress=
port=
adminUserName=
adminPassword=
source "${cosysesPath}/prepare-parameters.sh"

if [[ -z "${bindAddress}" ]]; then
  if [[ -f /.dockerenv ]]; then
    bindAddress="0.0.0.0"
  else
    bindAddress="127.0.0.1"
  fi
fi

if [[ -z "${port}" ]]; then
  port="27017"
fi

if [[ -z "${adminUserName}" ]]; then
  adminUserName="admin"
fi

if [[ -z "${adminPassword}" ]]; then
  adminPassword=$(echo "${RANDOM}" | md5sum | head -c 32)
  echo "Using generated password: ${adminPassword}"
fi

add-repository mongodb.list https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse https://www.mongodb.org/static/pgp/server-5.0.asc

install-package-from-deb libssl1.1 1.1.1f-1ubuntu2 http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb

install-package mongodb-org 5.0.20

echo "Allowing binding from: ${bindAddress}"
replace-file-content /etc/mongod.conf "bindIp: ${bindAddress}" "bindIp: 127.0.0.1"

echo "Using port: ${port}"
replace-file-content /etc/mongod.conf "port: ${port}" "port: 27017"

replace-file-content /etc/mongod.conf "security:" "#security:" 0
add-file-content-after /etc/mongod.conf "  authorization: enabled" "security:" 1

echo "Starting MongoDB"
if [[ -f /.dockerenv ]]; then
  install-package sudo

  mkdir -p /var/run/mongod && chown mongodb:mongodb /var/run/mongod
  sudo -H -u mongodb bash -c "/usr/bin/mongod -f /etc/mongod.conf --pidfilepath /var/run/mongod/mongodb.pid --fork"
else
  systemctl start mongod
fi

mongosh <<EOF
use admin;
db.createUser({
user: "${adminUserName}",
pwd: "${adminPassword}",
roles: [
       { role: "userAdminAnyDatabase", db: "admin" },
       { role: "readWriteAnyDatabase", db: "admin" }
     ]
})
EOF

if [[ -f /.dockerenv ]]; then
  echo "Stopping MongoDB"
  kill "$(cat /var/run/mongod/mongodb.pid)"

  echo "Creating start script at: /usr/local/bin/mongodb.sh"
  cat <<EOF > /usr/local/bin/mongodb.sh
#!/usr/bin/env bash
trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR
stop() {
  echo "Stopping MongoDB"
  sudo -H -u mongodb bash -c "/usr/bin/mongod -f /etc/mongod.conf --shutdown"
  exit
}
for command in "\$@"; do
  echo "Run: \${command}"
  /bin/bash "\${command}"
done
mkdir -p /var/run/mongod/
chown mongodb: /var/run/mongod/
sudo -H -u mongodb bash -c "rm -rf /var/run/mongod/mongodb.out && touch /var/run/mongod/mongodb.out"
echo "Starting MongoDB"
sudo -H -u mongodb bash -c "nohup /usr/bin/mongod -f /etc/mongod.conf --pidfilepath /var/run/mongod/mongodb.pid > /var/run/mongod/mongodb.out 2>&1 &" &
tail -f mongodb.out & wait \$!
EOF
  chmod +x /usr/local/bin/mongodb.sh
fi
