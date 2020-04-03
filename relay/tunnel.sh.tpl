#! /usr/bin/env bash

curl -L https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | bash -s -- "${userlogin}" "./tunnel_data/${sshkey}" "${port_location}"

