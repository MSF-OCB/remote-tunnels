#! /usr/bin/env bash
server_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQzSeGYj0r2P80lGa6qgRGi1OBgJ4q0qvXy+PlZ3BuP"
sshrelay="sshrelay.ocb.msf.org"
sshrelay_ip="15.188.17.148,185.199.180.11,2a05:d012:209:9a00:8e2a:9f6c:53be:df41"
sshrelay_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf"

declare -a relay_ports=("443" "22" "80")

zabbix_server_port="${1}"
priv_key="${2}"


if [ -z "${zabbix_server_port}" ]  || [ -z "${priv_key}" ]; then
  echo "Usage:"
  echo "  ${0} <zabbix_server_port> <priv_key>"
  exit 1
fi

if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
  ${localhost}       ${server_key}
  [${localhost}]:7105  ${server_key}
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
    -o LogLevel=ERROR \
    -o AddKeysToAgent=yes"
                     
/usr/local/bin/autossh \
      -M 0 \
      -N -T \
      -L 10052:localhost:10051 \
      ${ssh_common_options} \
      -i "${priv_key}" \
      -o "ExitOnForwardFailure=no" \
        -o ProxyCommand="ssh -W %h:%p \
            -i "${priv_key}" \
            ${ssh_common_options} \
            -o StrictHostKeyChecking=yes \
            -o UserKnownHostsFile=${known_hosts_file} \
            -p 22 \
            -l tunneller \
            ${sshrelay}" \
      -o "ExitOnForwardFailure=yes" \
      -o "IdentitiesOnly=yes" \
      -o "Compression=yes" \
      -o "ControlMaster=no" \
      -o "StrictHostKeyChecking=no" \
      -o "UserKnownHostsFile=/dev/null" \
      -l zbx_tnl \
      localhost \
      -i "${priv_key}" \
      -p "${zabbix_server_port}"

echo "Stopping the tunnel to Server..."
