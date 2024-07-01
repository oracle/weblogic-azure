#!/usr/bin/env bash

set -Eeuo pipefail

echo "Execute azure-credential-teardown.sh - Start------------------------------------------"

gh secret delete "AZURE_CREDENTIALS"
SERVICE_PRINCIPAL_NAME_WLS_AKS=$(gh variable get "SERVICE_PRINCIPAL_NAME_WLS_AKS")
az ad sp delete --id $(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME_WLS_AKS --query "[].appId" -o tsv| tr -d '\r\n')

echo "Execute azure-credential-teardown.sh - End--------------------------------------------"
