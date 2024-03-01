# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function connect_aks(){
    az aks get-credentials \
        -n $AKS_CLUSTER_NAME \
        -g $AKS_CLUSTER_RG_NAME \
        --overwrite-existing \
        --only-show-errors
}

function enable_promethues_metrics(){
    az extension remove --name aks-preview
    az extension add --name k8s-extension

    ### Use existing Azure Monitor workspace
    az aks update --enable-azure-monitor-metrics \
        --name ${AKS_CLUSTER_NAME} \
        --resource-group ${AKS_CLUSTER_RG_NAME} \
        --azure-monitor-workspace-resource-id "${AMA_WORKSPACE_ID}" \
        --only-show-errors

    utility_validate_status "Enable Promethues Metrics."

    #Verify that the DaemonSet was deployed properly on the Linux node pools
    #https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#managed-prometheus
    kubectl get ds ama-metrics-node --namespace=kube-system
    #if the deployment fails, $?=1.
    utility_validate_status "Validate promethues metrics is enabled."
}

# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration
function deploy_customize_scraping(){
    #create scrape config file
    cat <<EOF >prometheus-config
global:
  scrape_interval: 30s
scrape_configs:
- job_name: '${WLS_DOMAIN_UID}'
  kubernetes_sd_configs:
  - role: pod
    namespaces: 
      names: [${WLS_NAMESPACE}]
  basic_auth:
    username: ${WLS_ADMIN_USERNAME}
    password: ${WLS_ADMIN_PASSWORD}
EOF

    #validate the scrape config file
    local podNamesinKubeSystem=$(kubectl get pods -l rsName=ama-metrics -n=kube-system -o json | jq -r '.items[].metadata.name')
    mkdir promconfigvalidator
    for podname in ${podNamesinKubeSystem}
    do 
        kubectl cp -n=kube-system "${podname}":/opt/promconfigvalidator ./promconfigvalidator/promconfigvalidator 
        kubectl cp -n=kube-system "${podname}":/opt/microsoft/otelcollector/collector-config-template.yml ./promconfigvalidator/collector-config-template.yml
        chmod 500 ./promconfigvalidator/promconfigvalidator
    done

    if [ ! -f "./promconfigvalidator/promconfigvalidator" ]; then
        echo_stderr "Failed to download promconfigvalidator tool that is shipped inside the Azure Monitor metrics addon pod(s)."
        exit 1
    fi

    ./promconfigvalidator/promconfigvalidator --config "./prometheus-config" --otelTemplate "./promconfigvalidator/collector-config-template.yml"
    utility_validate_status "Validate prometheus-config using promconfigvalidator."

    kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system
    utility_validate_status "Create ama-metrics-prometheus-config in kube-system namespace."
}

function get_wls_monitoring_exporter_image_url() {
    local wlsToolingFamilyJsonFile=weblogic_tooling_family.json
    local imageUrl="ghcr.io/oracle/weblogic-monitoring-exporter:2.1.9"

    # download the json file that has well tested monitoring exporter image url from weblogic-azure repo.
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fsL "${gitUrl4WLSToolingFamilyJsonFile}" -o ${wlsToolingFamilyJsonFile}
    if [ $? -eq 0 ]; then
        imageURL=$(cat ${wlsToolingFamilyJsonFile} | jq  ".items[] | select(.key==\"WME\") | .imageURL" | tr -d "\"")
        echo "well tested monitoring exporter image url: ${imageURL}"
    fi

    echo_stdout "Use monitoring exporter image: ${imageURL} "
    export WME_IMAGE_URL=${imageUrl}
}

# https://github.com/oracle/weblogic-monitoring-exporter
function deploy_webLogic_monitoring_exporter(){
    local wlsVersion=$(kubectl -n ${WLS_NAMESPACE} get domain ${WLS_DOMAIN_UID} -o=jsonpath='{.spec.restartVersion}' | tr -d "\"")
    wlsVersion=$((wlsVersion+1))

    cat <<EOF >patch-file.json
[
    {
        "op": "replace",
        "path": "/spec/restartVersion",
        "value": "${wlsVersion}"
    },
    {
        "op": "add",
        "path": "/spec/monitoringExporter",
        "value": {
            "configuration": {
                "domainQualifier": true,
                "metricsNameSnakeCase": true,
                "queries": [
                    {
                        "applicationRuntimes": {
                            "componentRuntimes": {
                                "key": "name",
                                "prefix": "webapp_config_",
                                "servlets": {
                                    "key": "servletName",
                                    "prefix": "weblogic_servlet_",
                                    "values": "invocationTotalCount"
                                },
                                "type": "WebAppComponentRuntime",
                                "values": [
                                    "deploymentState",
                                    "contextRoot",
                                    "sourceInfo",
                                    "openSessionsHighCount"
                                ]
                            },
                            "key": "name",
                            "keyName": "app"
                        },
                        "key": "name",
                        "keyName": "server"
                    }
                ]
            },
            "image": "${WME_IMAGE_URL}",
            "port": 8080
        }
    }
]
EOF

    kubectl -n ${WLS_NAMESPACE} patch domain ${WLS_DOMAIN_UID} \
        --type=json \
        --patch-file patch-file.json
    utility_validate_status "Enable WebLogic Monitoring Exporter."

    local timestampBeforePatchingDomain=$(date +%s)
    local clusterName=$(kubectl get cluster -n ${WLS_NAMESPACE} -o json | jq -r '.items[0].metadata.name')
    local replicas=$(kubectl -n ${WLS_NAMESPACE} get cluster ${clusterName} -o json \
        | jq '. | .spec.replicas')

    # wait for the restart completed.
    utility_wait_for_pod_restarted \
      ${timestampBeforePatchingDomain} \
      ${replicas} \
      ${WLS_DOMAIN_UID} \
      ${checkPodStatusMaxAttemps} \
      ${checkPodStatusInterval}
}

function wait_for_keda_ready(){
    local ready=false
    local attempt=0

    while [[ "${ready}" == "false" && $attempt -le ${checkKedaMaxAttempt} ]]; do
        echo_stdout "Check if KEDA is ready, attempt: ${attempt}."
        ready=true

        local podnames=$(kubectl get pods -n ${KEDA_NAMESPACE} -o json | jq -r '.items[].metadata.name')
        for podname in ${podnames}
        do 
            kubectl get pod ${podname} -n ${KEDA_NAMESPACE} | grep "Running"

            if [ $? -eq 1 ];then
                ready=false
            fi
        done

        attempt=$((attempt + 1))
        sleep ${checkKedaInteval}
    done

    if [ ${attempt} -gt ${checkKedaMaxAttempt} ]; then
        echo_stderr "Failed to enable KEDA."
        exit 1
    fi

    echo "KEDA is running." 
}

# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/integrate-keda
function enable_keda_addon() {
    az extension add -n aks-preview

    local oidcEnabled=$(az aks show --resource-group $AKS_CLUSTER_RG_NAME --name $AKS_CLUSTER_NAME --query oidcIssuerProfile.enabled)
    local workloadIdentity=$(az aks show --resource-group $AKS_CLUSTER_RG_NAME --name $AKS_CLUSTER_NAME --query securityProfile.workloadIdentity)

    if [[ "${oidcEnabled,,}" == "false" || -z "${workloadIdentity}" ]]; then
        az aks update -g $AKS_CLUSTER_RG_NAME -n $AKS_CLUSTER_NAME --enable-workload-identity --enable-oidc-issuer
        utility_validate_status "Enable oidc and worload identity in AKS $AKS_CLUSTER_NAME."
    fi

    export OIDC_ISSUER_URL=$(az aks show -n $AKS_CLUSTER_NAME -g $AKS_CLUSTER_RG_NAME --query "oidcIssuerProfile.issuerUrl" -otsv)

    export KEDA_UAMI_CLIENT_ID=$(az identity show --resource-group $CURRENT_RG_NAME --name $KEDA_UAMI_NAME --query 'clientId' -otsv)
    local tenantId=$(az identity show --resource-group $CURRENT_RG_NAME --name $KEDA_UAMI_NAME --query 'tenantId' -otsv)

    kubectl create namespace ${KEDA_NAMESPACE}

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $KEDA_UAMI_CLIENT_ID
  name: $KEDA_SERVICE_ACCOUNT_NAME
  namespace: $KEDA_NAMESPACE
EOF
    
    local kedaFederatedName="kedaFederated$(date +%s)"
    az identity federated-credential create \
        --name $kedaFederatedName \
        --identity-name $uamiName \
        --resource-group $CURRENT_RG_NAME \
        --issuer $OIDC_ISSUER_URL \
        --subject system:serviceaccount:$KEDA_NAMESPACE:$KEDA_SERVICE_ACCOUNT_NAME \
        --audience api://AzureADTokenExchange

    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update

    helm install keda kedacore/keda \
        --namespace ${KEDA_NAMESPACE} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=${KEDA_SERVICE_ACCOUNT_NAME} \
        --set podIdentity.azureWorkload.enabled=true \
        --set podIdentity.azureWorkload.clientId=$KEDA_UAMI_CLIENT_ID \
        --set podIdentity.azureWorkload.tenantId=$tenantId

    #validate
    wait_for_keda_ready
}

function output(){
    local kedaServerAddress=$(az monitor account show -n ${AMA_NAME} -g ${CURRENT_RG_NAME} --query 'metrics.prometheusQueryEndpoint' -otsv)
    local clusterName=$(kubectl get cluster -n ${WLS_NAMESPACE} -o json | jq -r '.items[0].metadata.name')
    cat <<EOF >kedascalersample.yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-managed-prometheus-trigger-auth
  namespace: ${WLS_NAMESPACE}
spec:
  podIdentity:
      provider: azure-workload
      identityId: ${KEDA_UAMI_CLIENT_ID}
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: azure-managed-prometheus-scaler
  namespace: ${WLS_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: weblogic.oracle/v1
    kind: Cluster
    name: ${clusterName}
  minReplicaCount: 1
  maxReplicaCount: ${WLS_CLUSTER_SIZE}
  triggers:
  - type: prometheus
    metadata:
      serverAddress: ${kedaServerAddress}
      metricName: webapp_config_open_sessions_high_count
      query: sum(webapp_config_open_sessions_high_count{app="<your-app-name>"}) # Note: query must return a vector/scalar single element response
      threshold: '10'
      activationThreshold: '1'
    authenticationRef:
      name: azure-managed-prometheus-trigger-auth
EOF

    local base64ofKedaScalerSample=$(cat ./kedascalersample.yaml | base64)
    local result=$(jq -n -c \
        --arg kedaScalerServerAddress "$kedaServerAddress" \
        --arg base64ofKedaScalerSample "${base64ofKedaScalerSample}" \
        '{kedaScalerServerAddress: $kedaScalerServerAddress, base64ofKedaScalerSample: $base64ofKedaScalerSample}')
    echo "result is: $result"
    echo $result >$AZ_SCRIPTS_OUTPUT_PATH
}

# TBD see if we can query some of the metrics

# Main script
set -Eo pipefail

install_kubectl

install_helm

connect_aks

get_wls_monitoring_exporter_image_url

deploy_webLogic_monitoring_exporter

enable_promethues_metrics

deploy_customize_scraping

enable_keda_addon

output