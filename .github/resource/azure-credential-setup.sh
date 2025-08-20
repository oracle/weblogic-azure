#!/usr/bin/env bash

set -Eeuo pipefail

#############################################################
# Unified Azure credential setup script.
# Replaces the need to run both azure-credential-setup-wls-aks.sh
# and azure-credential-setup-wls-vm.sh when using the unified flow.
#
# Behavior:
# - Creates ONE Azure Service Principal.
# - Assigns Contributor + User Access Administrator roles.
# - Stores credentials JSON in AZURE_CREDENTIALS secret.
# - Exposes unified name via SERVICE_PRINCIPAL_NAME variable.
# - For backward compatibility also sets legacy variables
#   SERVICE_PRINCIPAL_NAME_WLS_AKS and SERVICE_PRINCIPAL_NAME_WLS_VM
#   to the same value so downstream workflows keep working.
#
# NOTE: Leaves the original per-target scripts untouched for users
# still invoking them directly.
#############################################################

echo "Execute unified azure-credential-setup.sh - Start-----------------------------"

# Derive repo name if not provided
REPO_NAME=${REPO_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo repo)")}
SUBSCRIPTION_ID=$(az account show --query id -o tsv | tr -d '\r\n')

SERVICE_PRINCIPAL_NAME="sp-${REPO_NAME}-wls-unified-$(date +%s)"
echo "Creating Azure Service Principal with name: ${SERVICE_PRINCIPAL_NAME}" >&2

AZURE_CREDENTIALS=$(az ad sp create-for-rbac \
  --name "${SERVICE_PRINCIPAL_NAME}" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --sdk-auth \
  --only-show-errors)

SP_ID=$(az ad sp list --display-name "${SERVICE_PRINCIPAL_NAME}" --query '[0].id' -o tsv | tr -d '\r\n') || true
if [[ -n "${SP_ID}" ]]; then
  az role assignment create --assignee "${SP_ID}" --scope "/subscriptions/${SUBSCRIPTION_ID}" --role "User Access Administrator" >/dev/null 2>&1 || \
    echo "Warning: secondary role assignment may have failed" >&2
else
  echo "Warning: could not resolve SP ID for secondary role assignment" >&2
fi

# Best-effort detection of existing secret
if gh secret list 2>/dev/null | grep -q '^AZURE_CREDENTIALS\b'; then
  echo "Notice: Overwriting existing AZURE_CREDENTIALS secret" >&2
fi

gh secret --repo $(gh repo set-default --view) set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}" >/dev/null

gh variable --repo $(gh repo set-default --view) set SERVICE_PRINCIPAL_NAME -b"${SERVICE_PRINCIPAL_NAME}" >/dev/null || true
gh variable --repo $(gh repo set-default --view) set SERVICE_PRINCIPAL_NAME_WLS_AKS -b"${SERVICE_PRINCIPAL_NAME}" >/dev/null || true
gh variable --repo $(gh repo set-default --view) set SERVICE_PRINCIPAL_NAME_WLS_VM -b"${SERVICE_PRINCIPAL_NAME}" >/dev/null || true

echo "Execute unified azure-credential-setup.sh - End-------------------------------"
