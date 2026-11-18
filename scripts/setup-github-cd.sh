#!/usr/bin/env bash
# One-time GitHub setup for the CD pipeline (.github/workflows/cd.yml).
# Run from the repo root by a repo admin, after terraform/bootstrap and envs/dev are applied:
#
#   CD_KEY=~/.ssh/ibimina-hub-cd scripts/setup-github-cd.sh
#
# Creates the "production" environment (deployments from main only) and stores:
#   variables  AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID   (OIDC, not secret)
#   secrets    SSH_PRIVATE_KEY   private half of the CD deploy key (its .pub is in dev.tfvars)
#              TF_VARS_DEV       contents of terraform/envs/dev/dev.tfvars (for the drift plan)
set -euo pipefail

REPO="${REPO:-masasu-salomon/ibimina-hub}"
CD_KEY="${CD_KEY:-$HOME/.ssh/ibimina-hub-cd}"
TFVARS="terraform/envs/dev/dev.tfvars"

[ -f "$CD_KEY" ] || { echo "Deploy key $CD_KEY not found"; exit 1; }
[ -f "$TFVARS" ] || { echo "$TFVARS not found"; exit 1; }

out() { terraform -chdir=terraform/bootstrap output -raw "$1"; }

echo "Creating the production environment (main only)..."
gh api -X PUT "repos/$REPO/environments/production" --input - >/dev/null <<'JSON'
{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}
JSON
gh api -X POST "repos/$REPO/environments/production/deployment-branch-policies" \
  -f name=main -f type=branch >/dev/null 2>&1 || true   # already there on a re-run

echo "Setting OIDC variables..."
gh variable set AZURE_CLIENT_ID       --env production -R "$REPO" -b "$(out azure_client_id)"
gh variable set AZURE_TENANT_ID       --env production -R "$REPO" -b "$(out azure_tenant_id)"
gh variable set AZURE_SUBSCRIPTION_ID --env production -R "$REPO" -b "$(out azure_subscription_id)"

echo "Setting secrets..."
gh secret set SSH_PRIVATE_KEY --env production -R "$REPO" < "$CD_KEY"
gh secret set TF_VARS_DEV     --env production -R "$REPO" < "$TFVARS"

gh variable list --env production -R "$REPO"
gh secret list --env production -R "$REPO"
echo "Done. The next merge to main deploys."
