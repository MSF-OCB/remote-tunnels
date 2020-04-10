#! /usr/bin/env bash

trap cleanup SIGINT SIGHUP
function cleanup() {
  rm -rf "${tmp_dir}"
  exit 1
}

user="${1}"
key_file="${2}"
dest_port="${3}"
tmp_dir="${4}"

if [ -z "${user}" ] || [ -z "${key_file}" ] || [ -z "${dest_port}" ]; then
  echo -e "Got user=\"${user}\", key_file=\"${key_file}\", dest_port=\"${dest_port}\"\n"
  echo    "Usage: create_tunnel.sh <user> <key_file> <dest_port>"
  exit 1
fi

if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

proxy_port=9006
known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
sshrelay1.msf.be,185.199.180.11                                       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0ynb9uL4ZD2qT/azc79uYON73GsHlvdyk8zaLY/gHq
sshrelay2.msf.be,15.188.17.148,2a05:d012:209:9a00:8e2a:9f6c:53be:df41 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf
EOF

echo -e "\nConnecting to project..."
echo    "You may be asked twice for the password - this is OK"
echo    "After the second password nothing will happen - this is OK"
echo -e "You will be tunnelled until you close this window\n"

echo -e "User: ${user}, key file: $(basename ${key_file}), destination port: ${dest_port}\n"

for relay in "sshrelay2.msf.be" "sshrelay1.msf.be"; do
  for port in 22 80 443; do

    echo -e "Attempting to connect via ${relay} using port ${port}\n"

    ssh -q -T -N \
        -D "${proxy_port}" \
        -i "${key_file}" \
        -F /dev/null \
        -o "ExitOnForwardFailure=yes" \
        -o "ServerAliveInterval=10" \
        -o "ServerAliveCountMax=5" \
        -o "ConnectTimeout=360" \
        -o "StrictHostKeyChecking=no" \
        -o "UserKnownHostsFile=/dev/null" \
        -o "ProxyCommand=ssh -W %h:%p \
                             -i ${key_file} \
                             -o StrictHostKeyChecking=yes \
                             -o UserKnownHostsFile=${known_hosts_file} \
                             -p ${port} \
                             tunneller@${relay}" \
        -p "${dest_port}" \
        "${user}@localhost"

    if [ $? -eq 0 ]; then
      exit 0
    else
      echo -e "\nConnection failed, retrying."
    fi

  done
done


