#! /usr/bin/env bash

user=
key_file=
port=

curl -L https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | bash -s -- ${user} ${key_file} ${port}

