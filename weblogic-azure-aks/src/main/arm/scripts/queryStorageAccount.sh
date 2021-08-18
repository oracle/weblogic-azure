export aksClusterRGName=$1
export aksClusterName=$2
export wlsDomainUID=$3

export wlsDomainNS="${wlsDomainUID}-ns"
export currentStorageAccount="null"

# Connect to AKS cluster
function connect_aks_cluster() {
    az aks get-credentials \
        --resource-group ${aksClusterRGName} \
        --name ${aksClusterName} \
        --overwrite-existing
}

function query_storage_account() {
    echo "install kubectl"
    az aks install-cli

    echo "get pv, pvc"
    pvcName=${wlsDomainUID}-pvc-azurefile
    pvName=${wlsDomainUID}-pv-azurefile
    
    ret=$(kubectl -n ${wlsDomainNS} get pvc ${pvcName} | grep "Bound")

    if [ -n "$ret" ]; then
        echo "pvc is bound to namespace ${wlsDomainNS}."
        # this is a workaround for update domain using marketplace offer.
        # the offer will create a new storage account in a new resource group.
        # remove the new storage account.
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