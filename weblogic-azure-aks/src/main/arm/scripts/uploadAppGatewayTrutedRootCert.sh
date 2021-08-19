# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

# upload trusted root certificate to Azure Application Gateway
# $1: resource group name
# $2: Application Gateway name
# $3: one line based64 string of the certificate data

# The value is used in setupNetworking.sh, please do not change it.
export appgwBackendSecretName='backend-tls'

echo "output certificate data to backend-cert.cer"
echo "$3" | base64 -d >backend-cert.cer

az network application-gateway root-cert create \
      --gateway-name $2  \
      --resource-group $1 \
      --name ${appgwBackendSecretName} \
      --cert-file backend-cert.cer

if [ $? -ne 0 ]; then
    echo "Failed to upload trusted root certificate to Application Gateway ${2}"
    exit 1
fi
