# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function install_azure_ingress() {
    local identityLength=$(az aks show -g ${AKS_CLUSTER_RG_NAME} -n ${AKS_CLUSTER_NAME} | jq '.identity | length')
    echo "identityLength ${identityLength}"

    if [ $identityLength -lt 1 ]; then
        echo "enable managed identity..."
        # Your cluster is using service principal, and you are going to update the cluster to use systemassigned managed identity.
        # After updating, your cluster's control plane and addon pods will switch to use managed identity, but kubelet will KEEP USING SERVICE PRINCIPAL until you upgrade your agentpool.
        az aks update -y -g ${AKS_CLUSTER_RG_NAME} -n ${AKS_CLUSTER_NAME} --enable-managed-identity

        utility_validate_status "Enable Applciation Gateway Ingress Controller for ${AKS_CLUSTER_NAME}."
    fi

    local agicEnabled=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${AKS_CLUSTER_RG_NAME} | jq '.addonProfiles.ingressApplicationGateway.enabled')
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

function validate_azure_ingress() {
    az aks get-credentials \
        --resource-group ${AKS_CLUSTER_RG_NAME} \
        --name ${AKS_CLUSTER_NAME} \
        --overwrite-existing
    local ret=$(kubectl get pod -n kube-system | grep "ingress-appgw-deployment-*" | grep "Running")
    if [[ -z "$ret" ]]; then
        echo_stderr "Failed to enable azure ingress."
        exit 1
    fi

    echo "appgw ingress is running."
}

# Main script
set -Eo pipefail

install_kubectl

install_azure_ingress

validate_azure_ingress
