#!/usr/bin/env python3
"""Dynamic Ansible inventory built from Terraform outputs.

Runs `terraform output -json` in terraform/envs/dev (override with TF_DIR, and
the terraform binary with TF_BIN) and builds two groups:

    bastion  ansible_host = bastion_public_ip (the only VM with a public IP)
    app      ansible_host = app_private_ip, reached by SSH *through* the bastion
             (ProxyCommand), plus what the app role needs: the registry host,
             the tenant ID for the ACR token exchange, the database URL

The app VM only accepts SSH from the bastion subnet, so its admin_cidrs (UFW)
is public_subnet_cidr. The bastion's SSH gate is the Azure NSG (admin /32s, plus
a temporary rule for the CD runner), see group_vars/bastion.yml.

The database URL is a sensitive output; it only lives in memory here and the
app role writes it to a root-only file with no_log.

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
APP_HOST = os.environ.get("TF_INVENTORY_HOSTNAME", "ibimina-hub")
BASTION_HOST = "ibimina-hub-bastion"
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
    required = ["bastion_public_ip", "app_private_ip", "ssh_user"]
    missing = [name for name in required if not outputs.get(name)]
    if missing:
        warn(f"Terraform outputs {missing} are required but missing. "
             "Is the state from before the bastion was added? Run terraform apply.")
        return empty_inventory()

    user = outputs["ssh_user"]
    bastion_ip = outputs["bastion_public_ip"]
    ssh_key = os.environ.get("ANSIBLE_PRIVATE_KEY_FILE")
    key_arg = f" -i {ssh_key}" if ssh_key else ""

    # The jump hop gets the same "new VM, new host key" treatment as the target
    # (ansible.cfg sets host_key_checking = False for the target itself).
    proxy = (
        "-o ProxyCommand=\"ssh -W %h:%p -q"
        " -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        f"{key_arg} {user}@{bastion_ip}\""
    )

    bastion_vars = {
        "ansible_host": bastion_ip,
        "ansible_user": user,
        "admin_cidrs": outputs.get("admin_cidrs") or [],
    }

    app_vars = {
        "ansible_host": outputs["app_private_ip"],
        "ansible_user": user,
        "ansible_ssh_common_args": proxy,
        # UFW on the app VM: SSH only from the bastion subnet.
        "admin_cidrs": [outputs.get("public_subnet_cidr") or "10.20.0.0/24"],
    }
    if outputs.get("app_port") is not None:
        app_vars["app_port"] = int(outputs["app_port"])
    if outputs.get("acr_login_server"):
        app_vars["app_acr_login_server"] = outputs["acr_login_server"]
        app_vars["app_image"] = f"{outputs['acr_login_server']}/ibimina-hub"
    if outputs.get("tenant_id"):
        app_vars["app_azure_tenant_id"] = outputs["tenant_id"]
    if outputs.get("database_url"):
        app_vars["app_database_url"] = outputs["database_url"]
    if outputs.get("app_url"):
        app_vars["app_public_url"] = outputs["app_url"]

    return {
        "bastion": {"hosts": [BASTION_HOST]},
        GROUP: {"hosts": [APP_HOST]},
        "_meta": {"hostvars": {BASTION_HOST: bastion_vars, APP_HOST: app_vars}},
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
