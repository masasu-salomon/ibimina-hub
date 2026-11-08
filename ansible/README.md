# Ansible: configure the server and deploy Ibimina Hub

Terraform (`terraform/`) creates an empty Ubuntu 22.04 VM on Azure. Ansible then
takes that VM from "empty Linux box" to "hardened server running the API":

1. **common** installs base packages, turns on automatic security updates and sets the time zone.
2. **hardening** locks down SSH, turns on the UFW firewall and fail2ban, and applies kernel network hardening.
3. **docker** installs Docker CE from Docker's signed apt repo with a hardened daemon config.
4. **app** pulls `ghcr.io/masasu-salomon/ibimina-hub:<tag>`, runs it locked down, checks `/health`
   and rolls back to the previous image if the check fails.

The playbook is **idempotent**: a second run reports `changed=0`.

```
ansible/
├── ansible.cfg                  settings (inventory folder, roles path, pipelining)
├── requirements.yml             collections: community.docker, community.general, ansible.posix
├── site.yml                     the playbook: hosts "app", runs the 4 roles
├── .ansible-lint                lint config (production profile)
├── group_vars/all.yml           app_image, app_tag, app_port, admin_cidrs, timezone
├── inventory/
│   ├── terraform_inventory.py   dynamic inventory from `terraform output -json`
│   └── hosts.example.ini        static fallback (placeholders only)
└── roles/
    ├── common/      tasks, handlers, defaults, templates, meta
    ├── hardening/   tasks, handlers, defaults, templates, meta
    ├── docker/      tasks, handlers, defaults, templates, meta
    └── app/         tasks (main.yml + container.yml), defaults, meta
```

## Prerequisites

| What | Why |
|------|-----|
| Linux, macOS or **WSL (Ubuntu)** on Windows | Ansible does not run natively on Windows |
| Python 3.10+, `ansible-core` 2.16+, `ansible-lint` | to run and lint the playbook |
| The SSH private key that matches the public key given to Terraform | to log in as `azureuser` |
| A VM created by `terraform apply` (see `terraform/README.md`) | something to configure |
| Terraform (optional) | only for the dynamic inventory |

Install Ansible in WSL (a virtualenv keeps it away from the system Python):

```bash
sudo apt update && sudo apt install -y python3-venv
python3 -m venv ~/.venvs/ansible
source ~/.venvs/ansible/bin/activate
pip install "ansible-core>=2.16,<2.18" ansible-lint
```

**SSH key in WSL:** files under `/mnt/c` show up with 777 permissions and `ssh` refuses
to use a key like that. Copy it into WSL's own home folder:

```bash
mkdir -p ~/.ssh && cp /mnt/c/Users/<you>/.ssh/id_rsa ~/.ssh/ && chmod 600 ~/.ssh/id_rsa
```

## Setup

```bash
cd <repo>/ansible
source ~/.venvs/ansible/bin/activate

# WSL only: /mnt/c folders are world-writable, so Ansible ignores ansible.cfg
# unless you point at it explicitly.
export ANSIBLE_CONFIG=$PWD/ansible.cfg

ansible-galaxy collection install -r requirements.yml
```

Set **admin_cidrs** to your public IP (the same value as `admin_cidrs` in your Terraform
tfvars). It is empty on purpose and the hardening role refuses to run without it, so
the firewall can never lock you out:

```bash
curl -s ifconfig.me          # e.g. 203.0.113.10  ->  use "203.0.113.10/32"
```

Pass it with `-e` each time, or put it in a git-ignored file:

```bash
mkdir -p group_vars/app
printf 'admin_cidrs:\n  - 203.0.113.10/32\n' > group_vars/app/local.yml   # ignored by git
```

## Inventory

### Dynamic (default): read straight from Terraform

`ansible.cfg` points at the `inventory/` folder. Ansible runs every executable in it, so it
runs `terraform_inventory.py`, which:

1. runs `terraform output -json` in `terraform/envs/dev` (change with `TF_DIR=...`),
2. puts one host, `ibimina-hub`, in the group **app** with
   `ansible_host` = `public_ip` output, `ansible_user` = `ssh_user` output and
   `app_port` = `app_port` output (so Ansible and the NSG rule always agree),
3. supports `--list` and `--host <name>` like any Ansible inventory script.

If Terraform isn't installed, the folder is wrong or there is no state, it prints the reason
to stderr and returns an **empty inventory** instead of crashing. Ansible shows that message
with an `[ERROR]` prefix, but nothing has failed; it just means "no hosts from Terraform".

```bash
ansible-inventory --graph                      # should show @app -> ibimina-hub
python3 inventory/terraform_inventory.py --list
TF_DIR=/path/to/terraform/envs/dev ansible-inventory --graph
TF_BIN=terraform.exe ansible-inventory --graph # WSL, when apply was run from PowerShell
```

Terraform state stays on the machine that ran `apply`. On that machine run `terraform init` once
in `terraform/envs/dev` (in the same environment you run Ansible from).

### Static fallback

Everyone else (or when Terraform is not available) uses the static file:

```bash
cp inventory/hosts.example.ini inventory/hosts.ini   # hosts.ini is git-ignored
# replace <VM_PUBLIC_IP> and <SSH_USER> (ask whoever ran terraform apply)
ansible-playbook -i inventory/hosts.ini site.yml
```

`*.ini` files are skipped when Ansible loads the `inventory/` folder, so the example file with
placeholders is never used by accident.

## Running it

```bash
ansible app -m ansible.builtin.ping              # can we log in?

ansible-playbook site.yml --check --diff         # dry run: what would change (after the first real run;
                                                 # on a brand-new VM Docker isn't there yet, so later tasks can't be previewed)
ansible-playbook site.yml                        # full run
ansible-playbook site.yml                        # run again: should end with changed=0

ansible-playbook site.yml --tags app -e app_tag=sha-1a2b3c4   # redeploy one image tag only
ansible-playbook site.yml --tags hardening                    # re-apply only the security settings
```

Add `--private-key ~/.ssh/id_rsa` if your key isn't the default one.

Check the result:

```bash
curl http://<VM_PUBLIC_IP>:3000/health           # {"status":"ok",...}
```

## What each role does

### common
- Waits for cloud-init to finish first-boot setup, so apt isn't locked on run 1.
- `apt update` only if the cache is older than an hour (`cache_valid_time: 3600`, so no change on run 2).
- Installs base packages (`curl`, `gnupg`, `python3-requests` for the Docker modules, ...).
- Turns on **unattended-upgrades** for daily **security** updates (`20auto-upgrades`). Ubuntu's default
  config only allows the `-security` pockets; our drop-in adds cleanup and keeps reboots manual.
- Sets the time zone to `Africa/Kigali`.

### hardening
- **Safety checks first:** fails with a clear message if `admin_cidrs` is empty, isn't valid IPv4 CIDRs,
  or contains `0.0.0.0/0`, and if the login user would not be in `AllowUsers`. Nothing is changed until
  these pass.
- **SSH:** drop-in `/etc/ssh/sshd_config.d/10-hardening.conf` (read before Azure's `50-cloud-init.conf`,
  and sshd keeps the first value it sees). Checked with `validate: sshd -t -f %s` before it is written.
  The handler tests the full config again (`sshd -t`) and only then restarts `ssh`.
- **UFW:** allows 22/tcp from each admin CIDR **before** switching the firewall on, allows the app port,
  default deny incoming / allow outgoing, logging on, then enables it.
- **fail2ban:** sshd jail in `jail.local` (5 tries in 10 min = 1 h ban, longer for repeat offenders). Bans go
  through UFW, and the admin CIDRs are never banned.
- **sysctl:** kernel network hardening in `/etc/sysctl.d/99-hardening.conf`.

### docker
- Removes Ubuntu's clashing packages (`docker.io`, `podman-docker`, ...).
- Downloads Docker's GPG key once to `/etc/apt/keyrings/docker.asc` and **checks its fingerprint**
  (`9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88`) before trusting it.
- Adds the repo with `signed-by=`, so this key can only sign Docker's packages and nothing else.
- Installs Docker CE and the buildx/compose plugins.
- `/etc/docker/daemon.json` (validated with `dockerd --validate`): log rotation (10 MB x 3 files),
  `no-new-privileges`, `live-restore` (containers keep running while Docker restarts), `icc: false`.
- Restarts Docker through a handler, flushed straight away so the app role uses the new config.
- Adds `azureuser` to the `docker` group (`append: true`, so other groups are kept).

### app
- Reads the running container with `docker_container_info` and saves its **image ID** as the
  previous image (the ID, not the tag: after pulling, `latest` points at the new image).
- Removes dangling images (the running one is never dangling, so rollback still works).
- Pulls `{{ app_image }}:{{ app_tag }}` (only reports a change if the image really changed).
- Runs the container: `ibimina-hub`, `restart_policy: unless-stopped`, port `{{ app_port }}:3000`,
  `read_only: true`, `tmpfs /tmp` (noexec, nosuid, 64 MB), `cap_drop: [ALL]`,
  `no-new-privileges:true`, 256 MB memory with no extra swap, a limit of 100 processes, and a Docker
  healthcheck on `/health`.
- Waits for `http://localhost:{{ app_port }}/health` to return 200 (`uri` with `retries`/`until`/`delay`).
- Secret environment variables go in `app_secret_env` (e.g. from ansible-vault). The container task
  then runs with `no_log`, so they never show in the output.

## Error handling and rollback

The deploy lives in a `block` / `rescue` / `always`:

```
block:   pull image -> start container -> wait for /health 200
rescue:  start the previous image ID again -> check it is healthy
         -> fail the play: "Deploy of X failed, so it was ROLLED BACK to Y, which is healthy."
always:  print the final status (OK / ROLLED BACK / FAILED)
```

If there was no previous container (the first deploy), the play fails with
"there was no previous container to roll back to" and tells you to check `docker logs`.

Other error handling:
- `apt` tasks wait up to 5 minutes for the apt lock instead of failing.
- All config files are validated before they replace the old ones (`sshd -t`, `dockerd --validate`).
- The inventory script never crashes. It explains what's missing and returns an empty inventory.

**Tested locally** against Docker (same role, container on a test port):

| Run | What | Result |
|-----|------|--------|
| 1 | fresh deploy | `changed=2`, health 200 |
| 2 | same again | **`changed=0`** |
| 3 | `-e app_tag=does-not-exist-123` | pull failed → rescued → "ROLLED BACK ... which is healthy" |
| 4 | an image that never answers `/health` | 6 health retries failed → old image ID started again → healthy |
| 5, 6 | back to `latest` | run 5 moves off the rollback ID, run 6 `changed=0` |

## Security hardening summary

| Area | Setting |
|------|---------|
| SSH | key only (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `AuthenticationMethods publickey`), `PermitRootLogin no`, `AllowUsers azureuser`, `MaxAuthTries 3`, `LoginGraceTime 30`, `ClientAliveInterval 300`, all forwarding off, `LogLevel VERBOSE` |
| Firewall | UFW default deny in, SSH only from `admin_cidrs`, app port open, logging on |
| Brute force | fail2ban sshd jail (aggressive mode, growing bans, admins never banned) |
| Kernel | `rp_filter`, no ICMP redirects (accept or send), no source routing, SYN cookies, ignore broadcast pings, log martians, `kptr_restrict`, `dmesg_restrict`, `suid_dumpable 0` |
| Updates | daily unattended security upgrades |
| Docker daemon | signed repo with fingerprint check, log rotation, `no-new-privileges`, `live-restore`, `icc false` |
| Container | read-only root, `cap_drop ALL`, `no-new-privileges`, memory and pids limits, noexec tmpfs, runs as the image's non-root `node` user, healthcheck |
| Secrets | none in the repo. `admin_cidrs`, real IPs and local inventories are git-ignored, `no_log` on secret env vars |

### Docker ports bypass UFW

Docker writes its own iptables rules for published ports, and those are checked **before** UFW's rules.
So `-p 3000:3000` is reachable even if UFW didn't allow it, and the UFW rule for port 3000 mostly
documents intent. **The Azure NSG is what really limits port 3000** (`app_allowed_cidrs` in Terraform,
plus the NSG's deny-all rule for everything else). SSH is not published by Docker, so for port 22
UFW, fail2ban and the NSG all apply.

### Accepted risks
- `host_key_checking = False`: the VM is recreated by Terraform and gets a new host key each time.
  The NSG only lets admin IPs reach SSH, which reduces the man-in-the-middle risk.
- Being in the `docker` group is effectively root on the host. Only `azureuser` (key-only, admin IPs only)
  is added.
- `app_tag: latest` is the default for convenience. Pass a commit tag (`-e app_tag=sha-...`) for
  repeatable deploys and easy rollbacks.

## Linting

```bash
ansible-lint                              # production profile, see .ansible-lint
ansible-playbook site.yml --syntax-check
```

Both pass with 0 failures and 0 warnings.

## Run evidence

Paste the recap lines from a real run against the VM here.

**Run 1 (fresh VM):**

```
PLAY RECAP *********************************************************************
ibimina-hub : ok=__  changed=__  unreachable=0  failed=0  skipped=__  rescued=0  ignored=0
```

**Run 2 (same command again, proves idempotency):**

```
PLAY RECAP *********************************************************************
ibimina-hub : ok=__  changed=0  unreachable=0  failed=0  skipped=__  rescued=0  ignored=0
```

**Health check:**

```
$ curl http://<VM_PUBLIC_IP>:3000/health
<paste output>
```
