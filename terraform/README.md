# Terraform: Ibimina Hub infrastructure (Azure)

This folder provisions the server Ibimina Hub runs on. It creates a private network,
a firewall and one Ubuntu VM. Terraform stops at "an empty Linux box I can SSH into".
Installing Docker, hardening the server and deploying the app is the job of
[`../ansible`](../ansible).

## What it builds

```text
Resource group  ibimina-hub-dev-rg
└── Virtual network  10.20.0.0/16                       (module: network)
    └── Subnet  10.20.1.0/24
        ├── Network security group                      (module: security)
        │     100  allow TCP 22    from admin_cidrs only
        │     110  allow TCP 3000  from app_allowed_cidrs (public API)
        │     4000 deny everything else inbound
        └── VM  Ubuntu 22.04, SSH key only              (module: compute)
              NIC + static public IP, boot diagnostics, no VM extensions
```

| Resource | Purpose |
|---|---|
| `azurerm_resource_group` | Holds everything. Deleting it removes the whole environment |
| `azurerm_virtual_network`, `azurerm_subnet` | The private network (Azure's equivalent of a VPC) |
| `azurerm_network_security_group` + 3 rules | Stateful firewall, attached to the subnet |
| `azurerm_public_ip`, `azurerm_network_interface` | Static public address and the VM's network card |
| `azurerm_linux_virtual_machine` | The app server |

## Layout

```text
terraform/
├── modules/                 reusable building blocks, no provider config, no hardcoded values
│   ├── network/             VNet + subnet
│   ├── security/            NSG, rules, subnet association
│   └── compute/             public IP, NIC, VM
└── envs/
    └── dev/                 one environment: calls the modules with dev values
        ├── versions.tf      Terraform and provider versions, provider config
        ├── main.tf          resource group, module calls, shared tags (locals)
        ├── variables.tf     every environment-specific input, with validation
        ├── outputs.tf       what Ansible and people need after apply
        └── dev.tfvars.example
```

To add another environment, copy `envs/dev` to `envs/staging` and give it its own
`.tfvars`. The modules stay the same.

## Prerequisites

- Terraform 1.6 or newer (`terraform version`)
- Azure CLI, logged in (`az login`)
- An RSA SSH key pair. Azure's VM resource only accepts RSA:

  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/ibimina-hub -N ""
  ```

## Initialise and apply

```bash
cd terraform/envs/dev

# 1. Tell the provider which subscription to use (nothing is committed).
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# 2. Your own values. dev.tfvars is ignored by Git.
cp dev.tfvars.example dev.tfvars
#    set admin_cidrs to your IP:   curl ifconfig.me   ->   ["x.x.x.x/32"]
#    set ssh_public_key_path to your .pub key

# 3. Download the provider and the modules.
terraform init

# 4. Check, then preview. Nothing is created yet.
terraform fmt -check -recursive ../..
terraform validate
terraform plan -var-file=dev.tfvars -out=dev.tfplan

# 5. Create it (about 2 minutes). Applies exactly the plan you reviewed.
terraform apply dev.tfplan

# 6. See the results.
terraform output
```

The plan should show `Plan: 11 to add, 0 to change, 0 to destroy.`

## Variables

All environment-specific values are variables. Nothing about a region, a size, an
IP address or a subscription is hardcoded in the `.tf` files.

| Variable | Default | Notes |
|---|---|---|
| `environment` | (required) | `dev`, `staging` or `prod`. Goes into names and tags |
| `location` | (required) | Azure region, e.g. `southafricanorth` |
| `vm_size` | (required) | Must be one of the small burstable sizes in the validation list |
| `admin_cidrs` | (required) | IPs allowed to SSH. `0.0.0.0/0` is rejected by validation |
| `subscription_id` | `null` | `null` means read `ARM_SUBSCRIPTION_ID` from the environment |
| `project_name` | `ibimina-hub` | Name prefix |
| `app_port` | `3000` | Port the API is published on |
| `app_allowed_cidrs` | `["0.0.0.0/0"]` | Who can reach the API |
| `ssh_public_key_path` / `ssh_public_key` | `~/.ssh/id_rsa.pub` / `null` | Path, or the key itself (useful in CI) |
| `admin_username` | `azureuser` | Login user Ansible connects as |
| `vnet_cidr`, `subnet_cidr` | `10.20.0.0/16`, `10.20.1.0/24` | Network ranges |
| `os_disk_size_gb` | `30` | OS disk size |
| `extra_tags` | `{}` | Merged into the default tags |

If a value is wrong, `plan` stops with a clear message instead of failing halfway
through `apply`. Examples are SSH open to the world, an unknown environment, or an
oversized VM.

**VM size:** some Azure student subscriptions block `Standard_B1s`
(`NotAvailableForSubscription`). Check what yours allows before choosing:

```bash
az vm list-skus --location southafricanorth --size Standard_B --all -o table
```

## Outputs

| Output | Example | Used by |
|---|---|---|
| `public_ip` | `102.37.x.x` | Ansible dynamic inventory (SSH target) |
| `ssh_user` | `azureuser` | Ansible (`ansible_user`) |
| `app_port` | `3000` | Ansible (port to publish) |
| `private_ip` | `10.20.1.4` | Reference |
| `app_url` | `http://102.37.x.x:3000/health` | You, after deploying |
| `ssh_command` | `ssh azureuser@102.37.x.x` | You |
| `resource_group_name`, `resource_group_id` | | Portal, cleanup |
| `vnet_id`, `subnet_id`, `nsg_id`, `vm_id` | `/subscriptions/.../...` | Reference, audits |

```bash
terraform output -raw public_ip
terraform output -json     # what ansible/inventory/terraform_inventory.py reads
```

## Remote state (optional)

By default the state file stays in `envs/dev/` on the laptop that ran `apply`. Git
ignores it because it can contain secrets. A team sharing one environment should
use one locked remote state instead. With HCP Terraform, add this inside the
`terraform {}` block in `versions.tf`:

```hcl
cloud {}
```

Then set `TF_CLOUD_ORGANIZATION` and `TF_WORKSPACE`, set the workspace's
execution mode to **Local**, and run `terraform login` and `terraform init`.

## Tear down

The VM costs money while it exists. Destroy it when you are done:

```bash
terraform destroy -var-file=dev.tfvars
terraform state list      # should print nothing
```

## CI

The `Terraform` job in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs
`terraform fmt -check`, `terraform init -backend=false` and `terraform validate` on
every pull request. It needs no cloud credentials. Security scanning of this code
(Checkov) is described in [`../SECURITY.md`](../SECURITY.md).
