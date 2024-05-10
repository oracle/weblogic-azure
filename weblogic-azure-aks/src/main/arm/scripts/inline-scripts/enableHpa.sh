# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function get_cluster_uid(){
  local clusterUid=$(kubectl get clusters -n ${WLS_NAMESPACE} -o=jsonpath='{.items[].metadata.name}')
  utility_validate_status "Obtain cluster UID."
  export WLS_CLUSTER_UID=${clusterUid}
}

function scaling_basedon_cpu(){
    kubectl autoscale cluster ${WLS_CLUSTER_UID} \
        --cpu-percent=${UTILIZATION_PERCENTAGE} \
        --min=1 \
        --max=${WLS_CLUSTER_SIZE} \
        -n ${WLS_NAMESPACE}
    utility_validate_status "Enable HPA based on CPU utilization."
}

function scaling_basedon_memory(){
  cat <<EOF >scaler-memory.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${WLS_CLUSTER_UID}
  namespace: ${WLS_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: weblogic.oracle/v1
    kind: Cluster
    name: ${WLS_CLUSTER_UID}
  minReplicas: 1
  maxReplicas: ${WLS_CLUSTER_SIZE}
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        averageUtilization: ${UTILIZATION_PERCENTAGE}
        type: Utilization
EOF

  kubectl apply -f scaler-memory.yaml
  utility_validate_status "Enable HPA based on memory utilization."
}

function check_kubernetes_metrics_server(){
  # $?=1 if there is no running kms pod.
  kubectl get pod -l k8s-app=metrics-server -n kube-system | grep "Running"
  # exit if $?=1
  utility_validate_status "There should be at least one pod of kubernetes metrics server running."
}

# Main script
set -Eo pipefail

install_kubectl

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RG_NAME

get_cluster_uid

check_kubernetes_metrics_server

if [ "$HPA_SCALE_TYPE" == "cpu" ]; then
  scaling_basedon_cpu
elif [ "$HPA_SCALE_TYPE" == "memory" ]; then
  scaling_basedon_memory
fi
