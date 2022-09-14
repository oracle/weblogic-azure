# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Inputs:
# AKS_CLUSTER_RESOURCEGROUP_NAME
# AKS_CLUSTER_NAME

echo "Script ${0} starts"

export currentStorageAccount="null"

# Connect to AKS cluster
function connect_aks_cluster() {
  az aks get-credentials \
    --resource-group ${AKS_CLUSTER_RESOURCEGROUP_NAME} \
    --name ${AKS_CLUSTER_NAME} \
    --overwrite-existing
}

function query_storage_account() {
  echo "install kubectl"
  az aks install-cli

  echo "get pv name"
  pvName=$(kubectl get pv -o json |
    jq '.items[] | select(.status.phase=="Bound") | [.metadata.name] | .[0]' |
    tr -d "\"")

  if [[ "${pvName}" != "null" ]] && [[ "${pvName}" != "" ]]; then
    # this is a workaround for update domain using marketplace offer.
    # the offer will create a new storage account in a new resource group if there is no storage attached.
    currentStorageAccount=$(kubectl get pv ${pvName} -o json | jq '. | .metadata.labels.storageAccount' | tr -d "\"")
  fi
}

function output_result() {
  echo ${currentStorageAccount}

  result=$(jq -n -c \
    --arg storageAccount $currentStorageAccount \
    '{storageAccount: $storageAccount}')
  echo "result is: $result"
  echo $result >$AZ_SCRIPTS_OUTPUT_PATH
}

connect_aks_cluster

query_storage_account

output_result
