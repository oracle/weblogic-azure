# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function wait_for_azure_ingress_ready() {
    local ready=false
    local attempt=0

    while [[ "${ready}" == "false" && $attempt -le ${checkAgicMaxAttempt} ]]; do
        echo_stdout "Check if ACIG is ready, attempt: ${attempt}."
        ready=true

        local ret=$(kubectl get pod -n kube-system | grep "ingress-appgw-deployment-*" | grep "Running")
        if [ -z "${ret}" ]; then
            ready=false
        fi

        attempt=$((attempt + 1))
        sleep ${checkAgicInterval}
    done

    if [ ${attempt} -gt ${checkAgicMaxAttempt} ]; then
        echo_stderr "Failed to enable Application Gateway Ingress Controler."
        exit 1
    fi

    echo "Application Gateway Ingress Controler is running."
}

# Main script
set -Eo pipefail

install_kubectl

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RG_NAME

wait_for_azure_ingress_ready
