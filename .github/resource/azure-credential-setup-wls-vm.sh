#!/usr/bin/env bash

set -Eeuo pipefail

echo "Execute azure-credential-setup.sh - Start------------------------------------------"

## Create Azure Credentials
REPO_NAME=$(basename `git rev-parse --show-toplevel`)
SERVICE_PRINCIPAL_NAME_WLS_VM="sp-${REPO_NAME}-$(date +%s)"
echo "Creating Azure Service Principal with name: $SERVICE_PRINCIPAL_NAME_WLS_VM"
SUBSCRIPTION_ID=$(az account show --query id -o tsv| tr -d '\r\n')

# Set base64 flag for line wrapping (GNU uses -w 0, BSD/macOS doesn't need it)
if [[ "$OSTYPE" == "darwin"* ]]; then
    w0=""
else
    w0="-w 0"
fi

SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name "${SERVICE_PRINCIPAL_NAME_WLS_VM}" --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 ${w0})
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

## Set the Azure Credentials as a secret in the repository
gh secret --repo $(gh repo set-default --view) set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}"
gh variable --repo $(gh repo set-default --view) set "SERVICE_PRINCIPAL_NAME_WLS_VM" -b"${SERVICE_PRINCIPAL_NAME_WLS_VM}"

echo "Execute azure-credential-setup.sh - End--------------------------------------------"
