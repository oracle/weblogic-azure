# Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function enable_aks_msi() {
    local identityLength=$(az aks show -g ${AKS_CLUSTER_RG_NAME} -n ${AKS_CLUSTER_NAME} | jq '.identity | length')
    echo "identityLength ${identityLength}"

    if [ $identityLength -lt 1 ]; then
        echo "enable managed identity..."
        # Your cluster is using service principal, and you are going to update the cluster to use systemassigned managed identity.
        # After updating, your cluster's control plane and addon pods will switch to use managed identity, but kubelet will KEEP USING SERVICE PRINCIPAL until you upgrade your agentpool.
        az aks update -y -g ${AKS_CLUSTER_RG_NAME} -n ${AKS_CLUSTER_NAME} --enable-managed-identity

        utility_validate_status "Enable managed identity for ${AKS_CLUSTER_NAME}."
    fi
}

function install_azure_ingress() {
    local agicEnabled=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${AKS_CLUSTER_RG_NAME} | 
        jq '.addonProfiles.ingressApplicationGateway.enabled')
    local agicGatewayId=""
    
    if [[ "${agicEnabled,,}" == "true" ]]; then
        agicGatewayId=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${AKS_CLUSTER_RG_NAME} |
            jq '.addonProfiles.ingressApplicationGateway.config.applicationGatewayId' |
            tr -d "\"")
    fi

    local appgwId=$(az network application-gateway show \
        -n ${APPGW_NAME} \
        -g ${CURRENT_RG_NAME} -o tsv --query "id")

    if [[ "${agicGatewayId}" != "${appgwId}" ]]; then
        az aks enable-addons -n ${AKS_CLUSTER_NAME} -g ${AKS_CLUSTER_RG_NAME} --addons ingress-appgw --appgw-id $appgwId
        utility_validate_status "Install app gateway ingress controller."
    fi
}

# Main script
set -Eo pipefail

enable_aks_msi

install_azure_ingress
