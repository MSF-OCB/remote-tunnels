#! /usr/bin/env bash

# We can enable this to auto-update git bash before launching the script.
#git update-git-for-windows -y

sshrelay1="sshrelay1.msf.be"
sshrelay1_ip="185.199.180.11"
sshrelay1_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC0ynb9uL4ZD2qT/azc79uYON73GsHlvdyk8zaLY/gHq"

sshrelay2="sshrelay2.msf.be"
sshrelay2_ip="15.188.17.148,2a05:d012:209:9a00:8e2a:9f6c:53be:df41"
sshrelay2_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsn2Dvtzm6jJyL9SJY6D1/lRwhFeWR5bQtSSQv6bZYf"

declare -a relays=("${sshrelay1}" "${sshrelay2}")
declare -a relay_ports=("443" "22" "80")

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

# Function dispatching to the correct platform dependent implementation
function kill_tunnels() {
  if [[ "$OSTYPE" == "msys" ]]; then
    kill_tunnels_msys
  elif [[ "$OSTYPE" == "linux-gnu"* ]] ||
       [[ "$OSTYPE" == "cygwin" ]]; then
    echo -e "INFO: detection of running tunnels has"\
            "not been implemented on this platform (${OSTYPE})."
  else
    echo -e "WARN: this platform is not supported! (${OSTYPE})"
  fi
  # Print a newline after this section
  echo ""
}

function kill_tunnels_msys {
  echo "Checking whether a tunnel is already running..."

  pid="$(netstat -ano | grep "[::1]:${proxy_port}" | awk '{ print $5 }')"

  if [[ "${pid}" =~ ^[0-9]+$ ]]; then
    echo "Killing existing tunnel process..."
    taskkill -PID "${pid}" -F
  fi
}

function print_banner() {
  do_print_banner \
    "Instructions to enter the passphrase:" \
    "1. Copy the passphrase for your tunnel key from Keeper" \
    "2. Do a right mouse click in this window and select paste," \
    "   no characters will be printed, this is normal" \
    "3. Press enter to confirm the passphrase" \
    "" \
    "You may be asked to enter the passphrase twice, this is normal"
}

function do_print_banner() (
  star_length=70
  stars="$(printf %-${star_length}s '' | tr ' ' '*')"

  function print_line() {
    _msg="${1}"

    echo -e "$(printf %-$((star_length - 1))s "* ${_msg}" '*')"
  }

  echo -e "${stars}"
  print_line ""
  for msg in "${@}"; do
    print_line "${msg}"
  done
  print_line ""
  echo -e "${stars}\n"
)

# Function to rewrite legacy user names to the ones actually used or to correct typos.
# We do this here because we cannot easily edit the keys that have been deployed to
# end user machines.
#
# The unifield user is not used anymore and neither should the tnl_legacy user.
# The tnl_legacy user is being phased out, but is currently still used by two
# projects (Capetown and Karachi).
function rewrite_username() {
  local user="${1}"
  echo "${user}" | \
    sed -e 's/^uf_/tnl_/' \
        -e 's/^unifield$/tnl_legacy/' \
        -e 's/karashi/karachi/' \
        -e 's/zyhtomyr/zhytomyr/'
}

( for i in $(ls tunnel_*.sh); do
    sed -i -e 's/EXIT$/EXIT HUP/' $i || true
  done ) 2>/dev/null

SSHAGENT=$(which ssh-agent 2>/dev/null)
SSHAGENTARGS="-s"
if [ -z "${SSH_AUTH_SOCK}" ] && [ -x "${SSHAGENT}" ]; then
  eval $(${SSHAGENT} ${SSHAGENTARGS})
fi

orig_user="${1}"
user="$(rewrite_username ${orig_user})"
key_file="${2}"
dest_port="${3}"
tmp_dir="${4}"
proxy_port=9006

if [ -z "${orig_user}" ] || [ -z "${key_file}" ] || [ -z "${dest_port}" ]; then
  echo -e "Got user=\"${orig_user}\", key_file=\"${key_file}\", dest_port=\"${dest_port}\"\n"
  echo    "Usage: create_tunnel.sh <user> <key_file> <dest_port>"
  exit 1
fi

if [ -z "${tmp_dir}" ]; then
  tmp_dir=$(mktemp -d)
fi

known_hosts_file="${tmp_dir}/known_hosts"

cat <<EOF > "${known_hosts_file}"
${sshrelay1},${sshrelay1_ip} ${sshrelay1_key}
${sshrelay2},${sshrelay2_ip} ${sshrelay2_key}
EOF

echo -e "\nConnecting to project..."

ssh_common_options="-o ServerAliveInterval=10 \
                    -o ServerAliveCountMax=5 \
                    -o ConnectTimeout=360 \
                    -o LogLevel=ERROR \
                    -o AddKeysToAgent=yes"
ssh_succes_msg="\nYou are now connected to the tunnel, please keep this window open.\nWhen finished, press control + c (Ctrl-C) to close the tunnel."

for repeat in $(seq 1 20); do
  for relay in "${relays[@]}"; do
    for relay_port in "${relay_ports[@]}"; do

      echo    "Starting tunnel, user: ${user}, key file: $(basename ${key_file}), destination port: ${dest_port}"
      echo -e "Connecting via ${relay} using port ${relay_port} (repeat: ${repeat})\n"

      kill_tunnels
      print_banner

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
                               -l tunneller \
                               ${relay}" \
          -p "${dest_port}" \
          -l "${user}" \
          localhost

      if [ $? -eq 0 ]; then
        exit 0
      else
        echo -e "\nConnection failed, retrying.\n"
        sleep 5 &
        wait
      fi

    done
  done
done

echo -e "\nNo more servers, please contact your IT support if the problem persists."
sleep 300 &
wait

