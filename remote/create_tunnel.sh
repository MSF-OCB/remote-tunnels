#! /usr/bin/env bash

# We can enable this to auto-update git bash before launching the script.
#git update-git-for-windows -y

trap cleanup EXIT
function cleanup() {
  if [ -d "${tmp_dir}" ]; then
    rm -rf "${tmp_dir}"
  fi
  if [ "${ssh_agent_launched}" = true ] && [ ! -z "${SSH_AGENT_PID}" ]; then
    kill ${SSH_AGENT_PID}
  elif [ ! -z "${SSH_AGENT_PID}" ]; then
    # Clear all identities from the running ssh-agent
    ssh-add -D
  fi
}

SSHAGENT=$(which ssh-agent 2>/dev/null)
SSHAGENTARGS="-s"
if [ -z "${SSH_AUTH_SOCK}" ] && [ -x "${SSHAGENT}" ]; then
  eval $(${SSHAGENT} ${SSHAGENTARGS})
  ssh_agent_launched=true
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
echo    "After entering the password nothing will happen - this is OK"
echo -e "You will be tunnelled until you close this window\n"

echo -e "User: ${user}, key file: $(basename ${key_file}), destination port: ${dest_port}\n"

# The below seemed to cause issues for some field users.
#if [ ! -z "${SSH_AGENT_PID}" ]; then
  # Add the key with a 40 minute lifetime
  # We make 6 connection attempts, each with a connection timeout of 360 seconds (= 6 min)
#  ssh-add -t 40m ${key_file}
#fi
ssh_common_options="-o ServerAliveInterval=10 \
                    -o ServerAliveCountMax=5 \
                    -o ConnectTimeout=360 \
                    -o LogLevel=ERROR \
                    -o AddKeysToAgent=yes"
ssh_succes_msg="\nYou are now connected to the tunnel, please keep this window open. When finished, press control + c to close the tunnel."

for relay in "sshrelay2.msf.be" "sshrelay1.msf.be"; do
  for port in 22 80 443; do

    echo -e "Connecting via ${relay} using port ${port}\n"

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

echo -e "\nNo more servers, please contact your IT support if the problem persists."
sleep 60 & wait

