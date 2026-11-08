#!/usr/bin/env python3
"""Dynamic Ansible inventory built from Terraform outputs.

Runs `terraform output -json` in terraform/envs/dev (override with TF_DIR, and
the terraform binary with TF_BIN) and puts the VM in the "app" group:

    ansible_host = public_ip output
    ansible_user = ssh_user output
    app_port     = app_port output (keeps Ansible and the NSG rule in sync)

If Terraform, the folder or the state is missing, it prints why on stderr and
returns an empty inventory instead of crashing, so you can switch to the static
fallback (inventory/hosts.example.ini).

Usage (Ansible calls it the same way):
    ./terraform_inventory.py --list
    ./terraform_inventory.py --host ibimina-hub
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

GROUP = "app"
HOSTNAME = os.environ.get("TF_INVENTORY_HOSTNAME", "ibimina-hub")
# ansible/inventory/terraform_inventory.py -> repo root is two folders up.
DEFAULT_TF_DIR = Path(__file__).resolve().parents[2] / "terraform" / "envs" / "dev"
TIMEOUT_SECONDS = 60


def warn(message):
    print(f"[terraform_inventory] {message}", file=sys.stderr)


def empty_inventory():
    return {"_meta": {"hostvars": {}}}


def read_outputs(tf_dir):
    """Return {name: value} from terraform output, or None on any problem."""
    terraform = shutil.which(os.environ.get("TF_BIN", "terraform"))
    if terraform is None:
        warn("terraform is not installed or not on PATH. "
             "Install it or use the static inventory: -i inventory/hosts.ini")
        return None

    if not tf_dir.is_dir():
        warn(f"Terraform folder not found: {tf_dir}. Set TF_DIR to the right path.")
        return None

    # cwd instead of -chdir: under WSL, TF_BIN=terraform.exe (Windows Terraform,
    # for state created from PowerShell) then gets the folder translated for it.
    try:
        result = subprocess.run(
            [terraform, "output", "-json", "-no-color"],
            cwd=tf_dir,
            capture_output=True,
            text=True,
            timeout=TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired:
        warn(f"terraform output took longer than {TIMEOUT_SECONDS}s, giving up.")
        return None
    except OSError as err:
        warn(f"could not run terraform: {err}")
        return None

    if result.returncode != 0:
        lines = [line.strip(" │╷╵") for line in result.stderr.splitlines()]
        lines = [line for line in lines if line]
        detail = next((line for line in lines if line.startswith("Error")),
                      lines[0] if lines else "no error message")
        warn(f"terraform output failed in {tf_dir}: {detail}")
        warn("Run `terraform init` there if this machine holds the state, "
             "otherwise use the static inventory: -i inventory/hosts.ini")
        return None

    try:
        raw = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        warn("terraform output did not return valid JSON.")
        return None

    if not raw:
        warn(f"no Terraform outputs in {tf_dir}. Has `terraform apply` been run "
             "on this machine? If the state lives elsewhere, use the static "
             "inventory: -i inventory/hosts.ini")
        return None

    return {name: item.get("value") for name, item in raw.items()}


def build_inventory(outputs):
    public_ip = outputs.get("public_ip")
    ssh_user = outputs.get("ssh_user")
    if not public_ip or not ssh_user:
        warn("Terraform outputs 'public_ip' and 'ssh_user' are required but missing.")
        return empty_inventory()

    hostvars = {"ansible_host": public_ip, "ansible_user": ssh_user}
    if outputs.get("app_port") is not None:
        hostvars["app_port"] = int(outputs["app_port"])

    return {
        GROUP: {"hosts": [HOSTNAME]},
        "_meta": {"hostvars": {HOSTNAME: hostvars}},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list", action="store_true", help="print the whole inventory")
    mode.add_argument("--host", metavar="NAME", help="print the variables of one host")
    args = parser.parse_args()

    tf_dir = Path(os.environ.get("TF_DIR", DEFAULT_TF_DIR)).expanduser()
    outputs = read_outputs(tf_dir)
    inventory = build_inventory(outputs) if outputs else empty_inventory()

    if args.host:
        print(json.dumps(inventory["_meta"]["hostvars"].get(args.host, {}), indent=2))
    else:
        print(json.dumps(inventory, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
