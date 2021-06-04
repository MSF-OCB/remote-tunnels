#! /usr/bin/env bash

sshrelay_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf"

relay_port="${1}"
relay="${2}"
priv_key="${3}"


if [ -z "${relay_port}" ] || [ -z "${relay}" ] || [ -z "${priv_key}" ]; then
  echo "Usage:"
  echo "  ${0} <relay_port> <relay_host> <priv_key>"
  exit 1
fi


if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
${relay}       ${sshrelay_key}
[${relay}]:80  ${sshrelay_key}
[${relay}]:443 ${sshrelay_key}
EOF


echo "Waiting for autossh to become available..."

while [ ! -x /usr/local/bin/autossh ]; do
  sleep 10
done


echo "Starting tunnel..."

/usr/local/bin/autossh \
  -M 0 \
  -T -N \
  -o "ExitOnForwardFailure=yes" \
  -o "ServerAliveInterval=10" \
  -o "ServerAliveCountMax=5" \
  -o "ConnectTimeout=360" \
  -o "UpdateHostKeys=yes" \
  -o "StrictHostKeyChecking=yes" \
  -o "UserKnownHostsFile=${known_hosts_file}" \
  -o "IdentitiesOnly=yes" \
  -o "Compression=yes" \
  -o "ControlMaster=no" \
  -R "${relay_port}":localhost:22 \
  -i "${priv_key}" \
  -p 443 \
  -l tunnel \
  "${relay}"

echo "Tunnel stopped..."

