#! /usr/bin/env bash
server_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQzSeGYj0r2P80lGa6qgRGi1OBgJ4q0qvXy+PlZ3BuP"
#ED25519 key fingerprint is SHA256:6Dqg2zfVE35WSP49rzCgzk7y1/A0ZE+hxBBhLtwkqwE 
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

known_hosts_file_server="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file_server}"
${localhost}       ${server_key}
[${localhost}]:7105  ${server_key}
EOF

echo "Waiting for autossh to become available..."

while [ ! -x /usr/local/bin/autossh ]; do
  sleep 10
done

echo "Starting tunnel to Server..."

/usr/local/bin/autossh \
  -M 0 \
  -N -T \
  -L 10052:localhost:10051 \
  -i "${priv_key}" \
  -o ProxyCommand="ssh -W %h:%p tunneller@sshrelay.ocb.msf.org" \
                             -o "ExitOnForwardFailure=yes" \
                             -o "ServerAliveInterval=10" \
                             -o "ServerAliveCountMax=5" \
                             -o "ConnectTimeout=360" \
                             -o "UpdateHostKeys=yes" \
                             -o "StrictHostKeyChecking=yes" \
                             -o "IdentitiesOnly=yes" \
                             -o "Compression=yes" \
                             -o "ControlMaster=no" \
                             -o "UserKnownHostsFile=${known_hosts_file_server}" \
                             -o "LogLevel=ERROR" \
                             -o "AddKeysToAgent=yes" \
  zbx_tnl@localhost \
  -i "${priv_key}" \
  -p "${zabbix_server_port}"

echo "Stopping the tunnel to Server..."
