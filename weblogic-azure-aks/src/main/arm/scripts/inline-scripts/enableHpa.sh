# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function scaling_basedon_cpu(){
    kubectl autoscale cluster ${WLS_CLUSTER_NAME} \
        --cpu-percent=50 \
        --min=1 \
        --max=${WLS_CLUSTER_SIZE} \
        -n WLS_NAMESPACE
}

function scaling_basedon_memory(){
    
}

function connect_aks(){
    az aks get-credentials \
        --resource-group ${AKS_CLUSTER_RG_NAME} \
        --name ${AKS_CLUSTER_NAME} \
        --overwrite-existing
}

function validate_scaler(){
    
}

# Main script
set -Eo pipefail

install_kubectl

connect_aks

if [ "$HPA_SCALE_TYPE" == "cpu" ]; then
  scaling_basedon_cpu
elif [ "$HPA_SCALE_TYPE" == "memory" ]; then
  scaling_basedon_memory
fi