# Terraform: Ibimina Hub infrastructure (Azure)

This folder provisions everything Ibimina Hub runs on: a private network split into
three subnets, a bastion host, an app VM with no public IP, a load balancer, a managed
PostgreSQL database and a private container registry. Terraform stops at "empty Linux
boxes I can reach through the bastion". Hardening them, installing Docker and deploying
the app is the job of [`../ansible`](../ansible).

## Two roots

| Root | Applied | State | Creates |
|---|---|---|---|
| `bootstrap/` | once, by an Owner of the subscription | local (git-ignored) | storage account + container for remote state; Entra ID app + service principal that GitHub Actions logs in as through OIDC (federated credential bound to the `production` environment); its Reader and state-blob roles |
| `envs/dev/` | whenever the infrastructure changes | remote, in the bootstrap storage account (`dev/terraform.tfstate`, locked by blob lease) | the environment below |

The split is there because the state store cannot hold its own state, and because the
CD identity should not be able to change the identity it runs as.

## What `envs/dev` builds

```text
Resource group  ibimina-hub-dev-rg
├── Virtual network 10.20.0.0/16                                (module: network)
│   ├── public subnet   10.20.0.0/24  + public NSG              (module: security)
│   │     100 SSH 22 from admin_cidrs          4000 deny all
│   │     └── Bastion VM, static public IP                      (module: compute, public_ip_enabled)
│   ├── private subnet  10.20.1.0/24  + private NSG
│   │     100 SSH 22 from the public subnet only
│   │     110 TCP 3000 from app_allowed_cidrs (LB keeps client IPs)
│   │     120 TCP 3000 from AzureLoadBalancer (probes)   4000 deny all
│   │     └── App VM, NO public IP, system-assigned identity    (module: compute, identity_enabled)
│   └── database subnet 10.20.2.0/24  + database NSG, delegated to PostgreSQL
│         100 TCP 5432 from the private subnet only      4000 deny all
│         └── PostgreSQL 16 Flexible Server, private access, TLS required   (module: database)
├── Private DNS zone *.private.postgres.database.azure.com, linked to the VNet
├── Standard load balancer + static public IP + DNS label       (module: loadbalancer)
│     rule TCP 80 -> 3000, HTTP probe /health every 5 s, outbound (SNAT) rule for the app VM
├── Container registry (Basic, admin user off)                  (module: registry)
│     AcrPull -> app VM identity, AcrPush -> CD identity
└── Network Contributor on the public NSG -> CD identity (temporary SSH rule per deploy)
```

## Layout

```text
terraform/
├── bootstrap/               state store + GitHub OIDC identity (applied once)
├── modules/                 reusable building blocks, no provider config, no hardcoded values
│   ├── network/             VNet, 3 subnets (one delegated), Postgres private DNS zone
│   ├── security/            3 NSGs, their rules (for_each), subnet associations
│   ├── compute/             Ubuntu VM: NIC, optional public IP, optional managed identity
│   ├── loadbalancer/        Standard LB, public IP + DNS label, probe, rule, outbound rule
│   ├── database/            PostgreSQL Flexible Server, database, server parameters
│   └── registry/            ACR + AcrPull / AcrPush role assignments
└── envs/
    └── dev/                 one environment: calls the modules with dev values
        ├── versions.tf      versions, azurerm backend (remote state), provider
        ├── main.tf          resource group, module calls, tags, moved blocks (F3 -> summative)
        ├── variables.tf     every environment-specific input, with validation
        ├── outputs.tf       what Ansible, CD and people need after apply
        └── dev.tfvars.example
```

`compute` is used twice (bastion and app VM) with different flags, which is the point
of a module. To add another environment, copy `envs/dev` to `envs/staging`, change the
backend `key` and give it its own `.tfvars`.

The `moved` blocks in `envs/dev/main.tf` carried the Formative 3 resources over to the
new module layout, so the existing VNet, subnet and NIC were updated in place.

## Prerequisites

- Terraform 1.6 or newer, Azure CLI logged in (`az login`) as an Owner of the subscription
- An RSA SSH key pair (Azure's VM resource only accepts RSA):
  `ssh-keygen -t rsa -b 4096 -f ~/.ssh/ibimina-hub -N ""`

## Apply

```bash
# Once: state store + CD identity
cd terraform/bootstrap
terraform init && terraform apply
terraform output            # put state_storage_account_name in envs/dev/versions.tf

# The environment
cd ../envs/dev
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
cp dev.tfvars.example dev.tfvars   # keys, admin /32s, cd_principal_object_id
terraform init
terraform fmt -check -recursive ../..
terraform validate
terraform plan -var-file=dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan         # about 10 minutes, PostgreSQL is the slow part
terraform output
```

## Variables (envs/dev)

| Variable | Default | Notes |
|---|---|---|
| `environment`, `location` | (required) | `dev`/`staging`/`prod`; Azure region |
| `vm_size`, `bastion_vm_size` | (required), `Standard_B2ats_v2` | Small burstable sizes only (validated) |
| `admin_cidrs` | (required) | /32s allowed to SSH into the bastion; `0.0.0.0/0` is rejected |
| `ssh_public_key` / `ssh_public_key_path` | `null` / `~/.ssh/id_rsa.pub` | Your key, pasted in (works in CI) or as a path |
| `extra_ssh_public_keys` | `[]` | Teammates' keys and the CD deploy key |
| `cd_principal_object_id` | `null` | From `bootstrap` output; gets AcrPush and rights on the bastion NSG |
| `app_port`, `app_allowed_cidrs` | `3000`, `["0.0.0.0/0"]` | API port behind the LB, who may call it |
| `vnet_cidr`, `public_subnet_cidr`, `private_subnet_cidr`, `database_subnet_cidr` | `10.20.0.0/16`, `.0.0/24`, `.1.0/24`, `.2.0/24` | Network ranges |
| `database_sku` | `B_Standard_B1ms` | PostgreSQL size |
| `dns_label` | `<project>-<environment>` | `<label>.<region>.cloudapp.azure.com` |
| `project_name`, `admin_username`, `os_disk_size_gb`, `extra_tags`, `subscription_id` | | as before |

## Outputs

| Output | Used by |
|---|---|
| `app_url`, `health_url`, `lb_public_ip` | people, CD smoke test |
| `bastion_public_ip`, `app_private_ip`, `ssh_user`, `public_subnet_cidr`, `admin_cidrs` | Ansible dynamic inventory |
| `acr_name`, `acr_login_server`, `tenant_id` | CD (push), Ansible (pull with the VM identity) |
| `database_url` (sensitive), `database_fqdn` | Ansible writes `DATABASE_URL` into the container's root-only `.env` |
| `resource_group_name`, `bastion_nsg_name` | CD (temporary SSH rule) |
| `ssh_command` | people: `ssh -J azureuser@<bastion> azureuser@10.20.1.4` |

## In the pipeline

- **CI** (`Terraform` job): `fmt -check`, then `init -backend=false` + `validate` on both
  roots. No cloud credentials needed.
- **Security** (`IaC scan`): Checkov on all of `terraform/`. Accepted findings carry a
  `#checkov:skip=<ID>:<reason>` next to the resource; see [`../SECURITY.md`](../SECURITY.md).
- **CD** (`Terraform plan (drift check)`): logs in with OIDC (read-only identity), runs
  `plan -detailed-exitcode` against the remote state and posts the summary to the run.
  The pipeline never applies; changes are applied by a person after review.

## Tear down

```bash
terraform -chdir=envs/dev destroy -var-file=dev.tfvars
terraform -chdir=bootstrap destroy     # only if the state store and CD identity should go too
```
