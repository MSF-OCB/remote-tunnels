#! /usr/bin/env bash

# We can enable this to auto-update git bash before launching the script.
#git update-git-for-windows -y

trap cleanup EXIT
function cleanup() {
  if [ -d "${tmp_dir}" ]; then
    rm -rf "${tmp_dir}"
  fi
  if [ ! -z "${SSH_AGENT_PID}" ]; then
    # Clear all identities from the running ssh-agent
    ssh-add -D
    kill ${SSH_AGENT_PID}
    unset SSH_AUTH_SOCK
  fi
}

( for i in $(ls tunnel_*.sh); do
    sed -i -e 's/EXIT$/EXIT HUP/' $i || true
  done ) 2>/dev/null

SSHAGENT=$(which ssh-agent 2>/dev/null)
SSHAGENTARGS="-s"
if [ -z "${SSH_AUTH_SOCK}" ] && [ -x "${SSHAGENT}" ]; then
  eval $(${SSHAGENT} ${SSHAGENTARGS})
fi

user="${1}"
key_file="${2}"
dest_port="${3}"
tmp_dir="${4}"
proxy_port=9006

if [ -z "${user}" ] || [ -z "${key_file}" ] || [ -z "${dest_port}" ]; then
  echo -e "Got user=\"${user}\", key_file=\"${key_file}\", dest_port=\"${dest_port}\"\n"
  echo    "Usage: create_tunnel.sh <user> <key_file> <dest_port>"
  exit 1
fi

if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
sshrelay1.msf.be,185.199.180.11                                       ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0ynb9uL4ZD2qT/azc79uYON73GsHlvdyk8zaLY/gHq
sshrelay2.msf.be,15.188.17.148,2a05:d012:209:9a00:8e2a:9f6c:53be:df41 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf
EOF

echo -e "\nConnecting to project..."
echo    "You may be asked for the password twice - this is OK"
echo -e "You will be tunnelled until you close this window\n"

echo -e "User: ${user}, key file: $(basename ${key_file}), destination port: ${dest_port}\n"

ssh_common_options="-o ServerAliveInterval=10 \
                    -o ServerAliveCountMax=5 \
                    -o ConnectTimeout=360 \
                    -o LogLevel=ERROR \
                    -o AddKeysToAgent=yes"
ssh_succes_msg="\nYou are now connected to the tunnel, please keep this window open.\nWhen finished, press control + c (Ctrl-C) to close the tunnel."

for repeat in $(seq 1 4); do
  for relay in "sshrelay2.msf.be" "sshrelay1.msf.be"; do
    for relay_port in 22 80 443; do

      echo -e "Connecting via ${relay} using port ${relay_port} (repeat: ${repeat})\n"

      ssh -T -N \
          -D "${proxy_port}" \
          -i "${key_file}" \
          -F /dev/null \
          ${ssh_common_options} \
          -o "ExitOnForwardFailure=yes" \
          -o "StrictHostKeyChecking=no" \
          -o "UserKnownHostsFile=/dev/null" \
          -o "PermitLocalCommand=yes" \
          -o "LocalCommand=echo -e \"${ssh_succes_msg}\"" \
          -o "ProxyCommand=ssh -W %h:%p \
                               -i ${key_file} \
                               ${ssh_common_options} \
                               -o StrictHostKeyChecking=yes \
                               -o UserKnownHostsFile=${known_hosts_file} \
                               -p ${relay_port} \
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
done

echo -e "\nNo more servers, please contact your IT support if the problem persists."
sleep 300 &
wait

