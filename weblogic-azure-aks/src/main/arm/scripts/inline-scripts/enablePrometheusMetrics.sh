# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function create_monitor_account_workspace(){
    local amaName="ama$(date +%s)"
    local ret=$(az monitor account create -n $amaName -g $CURRENT_RG_NAME --query "id" | tr -d "\"")
    utility_validate_status "Create Azure Monitor Account $amaName."

    if [ -z "$ret" ]; then  
        echo_stderr "Failed to create Azure Monitor Account."        
    fi

    export WORKSPACE_ID=$ret
}

function enable_promethues_metrics(){
    az extension remove --name aks-preview
    az extension add --name k8s-extension

    ### Use existing Azure Monitor workspace
    az aks update --enable-azure-monitor-metrics \
        --name ${AKS_CLUSTER_NAME} \
        --resource-group ${AKS_CLUSTER_RG_NAME} \
        --azure-monitor-workspace-resource-id "${WORKSPACE_ID}"

    utility_validate_status "Enable Promethues Metrics."

    #Verify that the DaemonSet was deployed properly on the Linux node pools
    #https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#managed-prometheus
    kubectl get ds ama-metrics-node --namespace=kube-system
    #if the deployment fails, $?=1.
    utility_validate_status "Validate promethues metrics is enabled."
}

# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration
function customize_scraping(){

}

