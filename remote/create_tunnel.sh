#! /usr/bin/env bash

user="${1}"
key_file="${2}"
dest_port="${3}"

if [ -z "${user}" ] || [ -z "${key_file}" ] || [ -z "${dest_port}" ]; then
  echo -e "Got user=\"${user}\", key_file=\"${key_file}\", dest_port=\"${dest_port}\"\n"
  echo    "Usage: create_tunnel.sh <user> <key_file> <dest_port>"
  exit 1
fi

proxy_port=9006
tmp_dir=$(mktemp -d)
known_hosts_file="${tmp_dir}/known_hosts"

curl -L https://github.com/msf-ocb/remote-tunnels/raw/master/remote/known_hosts -o ${known_hosts_file}

echo    "Connecting to project ${location}..."
echo    "You may be asked twice for the password - this is OK"
echo    "After the second password nothing will happen - this is OK"
echo -e "You will be tunnelled until you close this window\n"

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
        -o "UserKnownHostsFile=${known_hosts_file}" \
        -o "ProxyCommand=ssh -W %h:%p -p ${port} -i ${key_file} tunneller@${relay}" \
        -p "${dest_port}" \
        "${user}@localhost"

    if [[ $? -eq 0 ]]; then
      exit 0
    else
      echo -e "\nConnection failed, retrying."
    fi

  done
done

rm -rf "${tmp_dir}"

