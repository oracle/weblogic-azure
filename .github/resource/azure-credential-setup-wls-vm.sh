#!/usr/bin/env bash

set -Eeuo pipefail

echo "Execute azure-credential-setup.sh - Start------------------------------------------"

## Create Azure Credentials
SERVICE_PRINCIPAL_NAME_WLS_VM="sp-${REPO_NAME}-$(date +%s)"
echo "Creating Azure Service Principal with name: $SERVICE_PRINCIPAL_NAME_WLS_VM"
SUBSCRIPTION_ID=$(az account show --query id -o tsv| tr -d '\r\n')

SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME_WLS_VM} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 ${w0})
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

## Set the Azure Credentials as a secret in the repository
gh secret set "AZURE_CREDENTIALS" -b"${AZURE_CREDENTIALS}"
gh variable set "SERVICE_PRINCIPAL_NAME_WLS_VM" -b"${SERVICE_PRINCIPAL_NAME_WLS_VM}"

echo "Execute azure-credential-setup.sh - End--------------------------------------------"
