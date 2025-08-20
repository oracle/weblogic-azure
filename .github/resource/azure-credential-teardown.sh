#!/usr/bin/env bash

set -Eeuo pipefail

#############################################################
# Unified Azure credential teardown script.
# Mirrors the unified setup (azure-credential-setup.sh) and
# replaces the need to run both azure-credential-teardown-wls-aks.sh
# and azure-credential-teardown-wls-vm.sh when using the unified flow.
#
# Behavior:
# - Deletes AZURE_CREDENTIALS secret if present.
# - Retrieves any of SERVICE_PRINCIPAL_NAME, SERVICE_PRINCIPAL_NAME_WLS_AKS,
#   SERVICE_PRINCIPAL_NAME_WLS_VM (variables) and deletes the *single* SP
#   they reference (they all point to the same name in unified setup).
# - Ignores missing items gracefully.
#############################################################

echo "Execute unified azure-credential-teardown.sh - Start----------------------------------"

# Delete the AZURE_CREDENTIALS secret (ignore errors if it doesn't exist)
if gh secret list 2>/dev/null | grep -q '^AZURE_CREDENTIALS\b'; then
  gh secret --repo $(gh repo set-default --view) delete "AZURE_CREDENTIALS" || echo "Warning: failed to delete AZURE_CREDENTIALS" >&2
else
  echo "AZURE_CREDENTIALS secret not found (already removed)"
fi

# Try variables in priority order: unified then legacy aliases
VAR_CANDIDATES=(SERVICE_PRINCIPAL_NAME SERVICE_PRINCIPAL_NAME_WLS_AKS SERVICE_PRINCIPAL_NAME_WLS_VM)
SP_NAME=""
for var in "${VAR_CANDIDATES[@]}"; do
  if gh variable list 2>/dev/null | grep -q "^${var}\b"; then
    # Capture the value; gh variable get prints value only
    value=$(gh variable --repo $(gh repo set-default --view) get "$var" 2>/dev/null || true)
    if [[ -n "$value" ]]; then
      SP_NAME="$value"
      echo "Found service principal name via $var: $SP_NAME"
      break
    fi
  fi
done

if [[ -n "$SP_NAME" ]]; then
  APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv | tr -d '\r\n' || true)
  if [[ -n "$APP_ID" ]]; then
    echo "Deleting service principal appId=$APP_ID name=$SP_NAME" >&2
    az ad sp delete --id "$APP_ID" || echo "Warning: failed to delete service principal $APP_ID" >&2
  else
    echo "Service principal '$SP_NAME' not found in Azure (already deleted?)"
  fi
else
  echo "No service principal name variables found; skip SP deletion."
fi

# Optionally remove the variables themselves (clean slate)
for var in "${VAR_CANDIDATES[@]}"; do
  if gh variable list 2>/dev/null | grep -q "^${var}\b"; then
    gh variable --repo $(gh repo set-default --view) delete "$var" || echo "Warning: failed to delete variable $var" >&2
  fi
done

echo "Execute unified azure-credential-teardown.sh - End------------------------------------"
