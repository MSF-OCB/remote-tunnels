#! /usr/bin/env bash

sshrelay="sshrelay.ocb.msf.org"
sshrelay_ip="15.188.17.148,185.199.180.11,2a05:d012:209:9a00:8e2a:9f6c:53be:df41"
sshrelay_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf"

declare -a relay_ports=("443" "22" "80")

zabbix_server_port="${1}"
zabbix_user="${2}"
priv_key="${3}"
local_port="${4:-10052}"

remote_zabbix_port=10051


if [ -z "${zabbix_server_port}" ] || [ -z "${zabbix_user}" ] || [ -z "${priv_key}" ]; then
  echo "Usage:"
  echo "  ${0} <zabbix_server_port> <zabbix_user> <priv_key> [<local_port>]"
  exit 1
fi

if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
  ${sshrelay},${sshrelay_ip} ${sshrelay_key}
EOF

echo "Waiting for autossh to become available..."

while [ ! -x /usr/local/bin/autossh ]; do
  sleep 10
done

echo "Starting tunnel to Server..."

ssh_common_options="-F none \
                    -o ServerAliveInterval=10 \
                    -o ServerAliveCountMax=5 \
                    -o ConnectTimeout=360 \
                    -o LogLevel=ERROR"

ssh_succes_msg="Established connection to server on port ${zabbix_server_port}, opening port ${local_port}..."


AUTOSSH_GATETIME="0"
AUTOSSH_PORT="0"
AUTOSSH_MAXSTART="10"

while true; do
  for relay_port in "${relay_ports[@]}"; do
    /usr/local/bin/autossh \
      -T -N \
      -i "${priv_key}" \
      ${ssh_common_options} \
      -o "ExitOnForwardFailure=yes" \
      -o "StrictHostKeyChecking=no" \
      -o "UserKnownHostsFile=/dev/null" \
      -o "PermitLocalCommand=yes" \
      -o "LocalCommand=echo -e \"${ssh_succes_msg}\"" \
      -o "ProxyCommand=ssh -W %h:%p \
                           -i ${priv_key} \
                           ${ssh_common_options} \
                           -o StrictHostKeyChecking=yes \
                           -o UserKnownHostsFile=${known_hosts_file} \
                           -p ${relay_port} \
                           -l tunneller \
                           ${sshrelay}" \
      -p "${zabbix_server_port}" \
      -l "${zabbix_user}" \
      -L "${local_port}:localhost:${remote_zabbix_port}" \
      localhost
    done
  sleep 120
done

echo "Stopping the tunnel to server..."

