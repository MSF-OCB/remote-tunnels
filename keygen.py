#! /usr/bin/env python

import argparse
from functools import reduce
from itertools import repeat, chain
import os
import secrets
import string
import subprocess
import time
import zipfile
import tarfile

def args_parser():
  parser = argparse.ArgumentParser(description='Generate keys and launch script for SSH tunnels.')
  parser.add_argument('-l', '--location', type=str, required=True,             dest='msf_location')
  parser.add_argument('-p', '--port',     type=int, required=True,             dest='port')
  parser.add_argument('-n', '--num',      type=int, required=False, default=5, dest='amount')
  parser.add_argument('-u', '--user',     type=str, required=False,            dest='user')
  return parser

def generate_passwd():
  alphabet = string.ascii_letters + string.digits
  return ''.join(secrets.choice(alphabet) for i in range(8))

def to_csv(length, *strings):
  return ';'.join(list(chain(strings, repeat("", length)))[0:length]) + '\n'

def get_key_id(timestamp, num):
  return f"key_{str(timestamp)}{str(num)}"

def get_key_file_name(msf_location, key_id):
  return f"relay_{msf_location}_{key_id}"

def generate_keys(user, port, amount, batch_name, msf_location, timestamp):
  return reduce(concat3,
                map(lambda num: generate_key(user, port, batch_name, msf_location, timestamp, num),
                    range(1, amount + 1)))

def concat3(t1, t2):
  return (t1[0] + t2[0], t1[1] + t2[1], t1[2] + t2[2])

# Returns a 3-tuple containing the CSV line, the pub key content, and the paths to both key files
def generate_key(user, port, batch_name, msf_location, timestamp, num):
  passwd   = generate_passwd()
  key_id   = get_key_id(timestamp, num)
  key_file = os.path.join(batch_name, get_key_file_name(msf_location, key_id))
  do_generate_key(user, passwd, key_file, key_id)
  write_tunnel_zip(user, port, msf_location, batch_name, key_id, key_file)
  return (to_csv(5, key_id, passwd, msf_location),
          read_pub_key(key_file),
          [key_file, f"{key_file}.pub"])

def read_pub_key(key_file):
  with open(f"{key_file}.pub", 'r') as pub:
    return pub.readline(),

def do_generate_key(user, passwd, filename, key_id):
  subprocess.run(["ssh-keygen", "-q",
                                "-a", "100",
                                "-t", "ed25519",
                                "-N", passwd,
                                "-C", f"{user}_{key_id}",
                                "-f", filename])

def write_tunnel_zip(user, port, msf_location, batch_name, key_id, key_file):
  with open(key_file, 'r') as f:
    script = get_tunnel_script(user, port, key_id, f.read())
  with zipfile.ZipFile(f"{key_file}.zip", 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr(os.path.join(f"{msf_location}_{key_id}", f"tunnel.sh"), script)

def get_tunnel_script(user, port, key_id, key):
    return f"""#! /usr/bin/env bash
umask 0077

tmp_dir=$(mktemp -d)
cat <<EOF > "${{tmp_dir}}/{key_id}"
{key}
EOF

curl -L https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | bash -s -- "{user}" "${{tmp_dir}}/{key_id}" "{port}"

rm -rf "${{tmp_dir}}"
"""

def write_files(user, batch_name, csvs, pub_keys, files):
  csv_file_name     = os.path.join(batch_name, f"{batch_name}_index.csv")
  pub_key_file_name = os.path.join(batch_name, f"{user}")
  tar_file_name     = os.path.join(batch_name, f"{batch_name}_archive.tar.gz")

  write_lines(csv_file_name, to_csv(5, "Key", "Pass", "Location", "User", "Comment"), *csvs)
  write_lines(pub_key_file_name, *pub_keys)
  tar_files(tar_file_name, csv_file_name, pub_key_file_name, *files)

def write_lines(file_name, *lines):
  with open(file_name, 'w+') as f:
    list(map(f.write, lines))

def tar_files(tar_file_name, *files):
  with tarfile.open(tar_file_name, "w:gz") as tar:
    list(map(tar.add, files))

def print_info(user, port, batch_name):
  print(f"\nCreated batch: {batch_name}\n")
  print( "@nixos repo, do not forget to:")
  print(f"- copy (or add the content of) {user} to org-spec/keys")
  print(f"- add {user}.enable = true; to the users.users object @org-spec/hosts/benucXXX.nix (port={port})")
  print( "- add {user} = tunnelOnly; to org-spec/ocb_users.nix")
  print( "- commit, push,pull and nixos-rebuild in the relays and benuc {port}")
  print( "- Add the keys to keeper")

def go():
  args = args_parser().parse_args()
  if args.user is None:
    args.user = "uf_" + args.msf_location

  epoch_time = int(time.time())
  batch_name = "batch_" + args.msf_location + "_" + str(epoch_time)

  os.mkdir(batch_name)

  (csvs, pub_keys, key_files) = generate_keys(args.user, args.port, args.amount, batch_name, args.msf_location, epoch_time)
  write_files(args.user, batch_name, csvs, pub_keys, key_files)

  list(map(os.remove, key_files))

  print_info(args.user, args.port, batch_name)

go()

