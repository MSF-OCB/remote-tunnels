#! /usr/bin/env python

import argparse
import bisect
import json
import os
import re
import secrets
import string
import subprocess
import tarfile
import time

from dataclasses import dataclass
from functools   import reduce
from itertools   import repeat, chain

@dataclass(frozen=True)
class KeyData:
  msf_location: str
  host:         str
  amount:       int
  user:         str
  dry_run:      bool
  epoch_time:   int = int(time.time())

  def batch_name(self):
    return f"batch_{self.msf_location}_{self.epoch_time}"

  def key_id(self, num):
    return f"key_{self.epoch_time}{num}"

  def key_file_name(self, key_id):
    return f"relay_{self.msf_location}_{key_id}"

  def repo_path(self):
    return os.path.join(self.batch_name(), "nixos")

  def branch_name(self):
    return f"nixos_keygen_script_{self.batch_name()}"

  def port(self):
    if not os.path.isdir(self.repo_path()):
      raise FileNotFoundError("NixOS repo not cloned!")
    with open(os.path.join(self.repo_path(), "json", "tunnels.d", "tunnels.json"), 'r') as f:
      tunnels = json.load(f)
    per_host = tunnels["tunnels"]["per-host"]
    assert self.host in per_host, f"The host name {self.host} is not defined in tunnels.json, exiting."
    return per_host[self.host]["remote_forward_port"]


def args_parser():
  def_key_amount = 5
  parser = argparse.ArgumentParser(description='Generate keys and launch script for SSH tunnels.')
  parser.add_argument('-l', '--location', type=str,  required=True,  dest='msf_location',
                      help="The location of the MSF project, e.g. be_bruxelles")
  parser.add_argument('-s', '--server',   type=str,  required=True,  dest='host',
                      help="The remote server to which this key will give access, e.g. benuc002")
  parser.add_argument('-n', '--num',      type=int,  required=False, dest='amount', default=def_key_amount,
                      help=f"The amount of keys to generate, defaults to {def_key_amount}")
  parser.add_argument('-u', '--user',     type=str,  required=False, dest='user',
                      help="The user that will be used to connect with the generated keys, defaults to \"tnl_<msf_location>\"")
  parser.add_argument('--dry-run', required=False, dest='dry_run', action='store_true',
                      help="Run the script without making any changes to github")
  return parser


def generate_passwd():
  alphabet = string.ascii_letters + string.digits
  return ''.join(secrets.choice(alphabet) for i in range(8))


def to_csv(length, *strings):
  return ';'.join(list(chain(strings, repeat("", length)))[0:length]) + '\n'


def generate_keys(data,):
  return reduce(concat3, map(lambda num: generate_key(data, num),
                             range(1, data.amount + 1)))


def concat3(t1, t2):
  return (t1[0] + t2[0], t1[1] + t2[1], t1[2] + t2[2])


# Returns a 3-tuple containing the CSV line, the pub key content, and the paths to both key files
def generate_key(data, num):
  print(f"generating key {num} of {data.amount}", flush=True)
  passwd   = generate_passwd()
  key_id   = data.key_id(num)
  key_file = os.path.join(data.batch_name(), data.key_file_name(key_id))
  do_generate_key(data.user, passwd, key_file, key_id)
  write_tunnel_script(data, key_id, key_file)
  return (to_csv(5, key_id, passwd, data.msf_location),
          read_pub_key(key_file),
          [key_file, f"{key_file}.pub"])


def read_pub_key(key_file):
  with open(f"{key_file}.pub", 'r') as pub:
    return pub.readline().rstrip(),


def do_generate_key(user, passwd, filename, key_id):
  subprocess.run(["ssh-keygen", "-q",
                                "-a", "100",
                                "-t", "ed25519",
                                "-N", passwd,
                                "-C", "",
                                "-f", filename])


def write_tunnel_script(data, key_id, key_file):
  script_name = os.path.join(data.batch_name(), f"tunnel_{key_id}.sh")
  with open(key_file, 'r') as f:
    write_lines(script_name, tunnel_script(data, key_id, f.read()))


def tunnel_script(data, key_id, key):
  return f"""#! /usr/bin/env bash
umask 0077

trap cleanup EXIT HUP
function cleanup() {{
  if [ -d "${{tmp_dir}}" ]; then
    rm -rf "${{tmp_dir}}"
  fi
}}

tmp_dir=$(mktemp -d)
key_file="${{tmp_dir}}"/{data.msf_location}_{key_id}
cat <<EOF > "${{key_file}}"
{key}
EOF

curl --connect-timeout 90 \\
     --retry 5 \\
     --location \\
     https://github.com/msf-ocb/remote-tunnels/raw/master/remote/create_tunnel.sh | \\
  bash -s -- "{data.user}" "${{key_file}}" "{data.port()}" "${{tmp_dir}}"\n
"""


def write_files(data, csvs, pub_keys, files):
  csv_file_name     = os.path.join(data.batch_name(), f"{data.batch_name()}_index.csv")
  tar_file_name     = os.path.join(data.batch_name(), f"{data.batch_name()}_archive.tar.gz")

  write_lines(csv_file_name, to_csv(5, "Key", "Pass", "Location", "User", "Comment"), *csvs)
  tar_files(tar_file_name, csv_file_name, *files)


def write_lines(file_name, *lines):
  with open(file_name, 'w+') as f:
    list(map(f.write, lines))


def tar_files(tar_file_name, *files):
  with tarfile.open(tar_file_name, "w:gz") as tar:
    list(map(tar.add, files))


def update_nixos_config(data, pub_keys):
  rel_users_path = os.path.join("json", "users.json")
  update_nixos_users(data, rel_users_path)

  rel_keys_path = os.path.join("json", "keys.json")
  update_nixos_keys(data, rel_keys_path, pub_keys)

  commit_nixos_config(data, rel_users_path, rel_keys_path)


def update_nixos_users(data, rel_users_path):
  users_path = os.path.join(data.repo_path(), rel_users_path)
  with open(users_path, 'r') as f:
    users = json.load(f)
  per_host = users["users"]["per-host"]
  per_host.setdefault(data.host, dict()).setdefault("enable", dict())
  per_host[data.host]["enable"][data.user] = "remoteTunnel"
  with open(users_path, 'w') as f:
    json.dump(users, f, indent=2, sort_keys=True)


def update_nixos_keys(data, rel_keys_path, pub_keys):
  keys_path = os.path.join(data.repo_path(), rel_keys_path)

  with open(keys_path, 'r') as f:
    keys = json.load(f)

  keys_dict = keys["keys"]
  keys_dict.setdefault(data.user, dict()).setdefault("public_keys", list())
  keys_dict[data.user]["public_keys"].extend(pub_keys)

  with open(keys_path, 'w') as f:
    json.dump(keys, f, indent=2, sort_keys=True)


def commit_nixos_config(data, rel_users_path, rel_keys_path):
  subprocess.run(["git", "-C", data.repo_path(), "checkout", "-b", data.branch_name()])
  subprocess.run(["git", "-C", data.repo_path(), "add", rel_users_path, rel_keys_path])
  subprocess.run(["git", "-C", data.repo_path(),
                         "-c", 'user.name="OCB NixOS Robot"',
                         "-c", 'user.email="69807852+nixos-ocb@users.noreply.github.com"',
                         "commit",
                         "--message", f"Commit keygen changes, batch id {data.batch_name()}",
                         "--message", f"(x-nixos:rebuild:relay_port:{data.port()})"])
  subprocess.run(["git", "-C", data.repo_path(), "push", "--set-upstream", "origin", data.branch_name()] +
                 (["--dry-run"] if data.dry_run else []))


def ensure_present(x, xs):
  xs.sort()
  ix = bisect.bisect_left(xs, x)
  if ix == len(xs) or xs[ix] != x:
    xs.insert(ix, x)
  return None


def clone_nixos(data):
  subprocess.run(["git", "clone", "git@github.com:MSF-OCB/NixOS-OCB-config.git", data.repo_path()])


def print_info(data):
  green_colour = '\033[92m'
  blue_colour  = '\033[94m'
  red_colour   = '\033[93m'
  underline    = '\033[4m'
  end_format   = '\033[0m'

  pr_url = f"https://github.com/MSF-OCB/NixOS-OCB-config/pull/new/{data.branch_name()}"

  print(f"\n{green_colour}Created batch: {data.batch_name()}{end_format}\n")
  print( "Visit the following URL to create a pull request:")
  print(f"  {blue_colour}{underline}{pr_url}{end_format}\n")
  print(f"{red_colour}Do not forget to add the keys to keeper!{end_format}\n")


def validate_data(data):
  validate_user(data.user)
  validate_location(data.msf_location)


def validate_user_pattern():
  return r'[a-z][-_a-z0-9]+[a-z0-9]'


def validate_location(msf_location):
  do_validate(msf_location,
              r'[a-z]{2}_' + validate_user_pattern(),
"""Wrong location provided ("{input_data}"). The location should match the following pattern: {pattern}
This means that the location should:
  * Only contain lower-case alphanumerical characters, dashes and underscores
  * Start with the two-character ISO country code followed by an underscore
  * Following that have a project name which is at least three characters long and starts with a letter
  * Not end by a dash or an underscore""")


def validate_user(username):
  do_validate(username,
              validate_user_pattern(),
"""Wrong user name provided ("{input_data}"). The user name should match the following pattern: {pattern}
This means that the username should:
  * Only contain lower-case alphanumerical characters, dashes and underscores
  * Not start or end by a dash or an underscore, not start by a number
  * Be at least three characters long""")


def do_validate(input_data, regex, message):
  pattern = re.compile(regex)
  if not bool(pattern.fullmatch(input_data)):
    raise ValueError(message.format(input_data = input_data,
                                    pattern = pattern.pattern))


def go():
  args = args_parser().parse_args()
  data = KeyData(args.msf_location.lower(),
                 args.host.lower(),
                 args.amount,
                 (args.user or "tnl_" + args.msf_location).lower(),
                 args.dry_run)
  validate_data(data)

  os.mkdir(data.batch_name())
  clone_nixos(data)
  (csvs, pub_keys, key_files) = generate_keys(data)
  write_files(data, csvs, pub_keys, key_files)
  update_nixos_config(data, pub_keys)
  list(map(os.remove, key_files))
  print_info(data)


if __name__ == "__main__":
  go()

