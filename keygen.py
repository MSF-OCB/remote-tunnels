#! /usr/bin/env python

import argparse
import os
import secrets
import string
import subprocess
import tarfile
import time
import zipfile

from dataclasses import dataclass
from functools   import reduce
from itertools   import repeat, chain

@dataclass(frozen=True)
class KeyData:
  msf_location: str
  port:         int
  amount:       int
  user:         str
  epoch_time:   int = int(time.time())

  def batch_name(self):
    return f"batch_{self.msf_location}_{self.epoch_time}"

  def key_id(self, num):
    return f"key_{self.epoch_time}{num}"

  def key_file_name(self, key_id):
    return f"relay_{self.msf_location}_{key_id}"

def args_parser():
  def_key_amount=5
  parser = argparse.ArgumentParser(description='Generate keys and launch script for SSH tunnels.')
  parser.add_argument('-l', '--location', type=str, required=True,  dest='msf_location',
                      help="The location of the MSF project, e.g. be_bruxelles")
  parser.add_argument('-p', '--port',     type=int, required=True,  dest='port',
                      help="The tunnel port of the remote server to which this key gives access, e.g. 6002")
  parser.add_argument('-n', '--num',      type=int, required=False, dest='amount', default=def_key_amount, 
                      help=f"The amount of keys to generate, defaults to {def_key_amount}")
  parser.add_argument('-u', '--user',     type=str, required=False, dest='user',
                      help="The user that will be used to connect with the generated keys, defaults to \"uf_<location>\"")
  return parser

def generate_passwd():
  alphabet = string.ascii_letters + string.digits
  return ''.join(secrets.choice(alphabet) for i in range(8))

def to_csv(length, *strings):
  return ';'.join(list(chain(strings, repeat("", length)))[0:length]) + '\n'

def generate_keys(data,):
  return reduce(concat3,
                map(lambda num: generate_key(data, num),
                    range(1, data.amount + 1)))

def concat3(t1, t2):
  return (t1[0] + t2[0], t1[1] + t2[1], t1[2] + t2[2])

# Returns a 3-tuple containing the CSV line, the pub key content, and the paths to both key files
def generate_key(data, num):
  passwd   = generate_passwd()
  key_id   = data.key_id(num)
  key_file = os.path.join(data.batch_name(), data.key_file_name(key_id))
  do_generate_key(data.user, passwd, key_file, key_id)
  write_tunnel_zip(data, key_id, key_file)
  return (to_csv(5, key_id, passwd, data.msf_location),
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

def write_tunnel_zip(data, key_id, key_file):
  with open(key_file, 'r') as f:
    script = get_tunnel_script(data, key_id, f.read())
  with zipfile.ZipFile(f"{key_file}.zip", 'w', zipfile.ZIP_DEFLATED) as zf:
    zf.writestr(os.path.join(f"{data.msf_location}_{key_id}", f"tunnel.sh"), script)

def get_tunnel_script(data, key_id, key):
    return f"""#! /usr/bin/env bash
umask 0077

trap ctrl_c SIGINT
function ctrl_c() {{
  echo "Trapped Ctrl-C, exiting"
  rm -rf "${{tmp_dir}}"
  exit 1
}}

tmp_dir=$(mktemp -d)
cat <<EOF > "${{tmp_dir}}/{key_id}"
{key}
EOF

curl -L https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | bash -s -- "{data.user}" "${{tmp_dir}}/{key_id}" "{data.port}"
"""

def write_files(data, csvs, pub_keys, files):
  csv_file_name     = os.path.join(data.batch_name(), f"{data.batch_name()}_index.csv")
  pub_key_file_name = os.path.join(data.batch_name(), f"{data.user}")
  tar_file_name     = os.path.join(data.batch_name(), f"{data.batch_name()}_archive.tar.gz")

  write_lines(csv_file_name, to_csv(5, "Key", "Pass", "Location", "User", "Comment"), *csvs)
  write_lines(pub_key_file_name, *pub_keys)
  tar_files(tar_file_name, csv_file_name, pub_key_file_name, *files)

def write_lines(file_name, *lines):
  with open(file_name, 'w+') as f:
    list(map(f.write, lines))

def tar_files(tar_file_name, *files):
  with tarfile.open(tar_file_name, "w:gz") as tar:
    list(map(tar.add, files))

def print_info(data):
  print(f"\nCreated batch: {data.batch_name()}\n")
  print( "@nixos repo, do not forget to:")
  print(f"- copy (or add the content of) {data.user} to org-spec/keys")
  print(f"- add {data.user}.enable = true; to the users.users object @org-spec/hosts/benucXXX.nix (port={data.port})")
  print( "- add {data.user} = tunnelOnly; to org-spec/ocb_users.nix")
  print( "- commit, push,pull and nixos-rebuild in the relays and benuc {data.port}")
  print( "- Add the keys to keeper")

def go():
  args = args_parser().parse_args()
  data = KeyData(args.msf_location, args.port, args.amount, args.user or "uf_" + args.msf_location)

  os.mkdir(data.batch_name())
  (csvs, pub_keys, key_files) = generate_keys(data)
  write_files(data, csvs, pub_keys, key_files)
  list(map(os.remove, key_files))
  print_info(data)

go()

