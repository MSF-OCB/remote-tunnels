#! /usr/bin/env bash

relay_port="${1}"
relay="${2}"
priv_key="${3}"

if [ -z "${relay_port}" ] || [ -z "${relay}" ] || [ -z "${priv_key}" ]; then
  echo "Usage:"
  echo "  ${0} <relay_port> <relay_host> <priv_key>"
  exit 1
fi

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
  -o "UserKnownHostsFile=/root/.ssh/known_hosts" \
  -o "IdentitiesOnly=yes" \
  -o "Compression=yes" \
  -o "ControlMaster=no" \
  -R "${relay_port}":localhost:22 \
  -i "${priv_key}" \
  -p 443 \
  -l tunnel \
  "${relay}"

echo "Tunnel stopped..."

