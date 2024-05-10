# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#!/bin/bash

function enable_promethues_metrics(){
    # See https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#enable-prometheus-and-grafana
    az extension add --name k8s-extension && true

    ### Use existing Azure Monitor workspace
    az aks update --enable-azure-monitor-metrics \
        --name ${AKS_CLUSTER_NAME} \
        --resource-group ${AKS_CLUSTER_RG_NAME} \
        --azure-monitor-workspace-resource-id "${AMA_WORKSPACE_ID}" \
        --only-show-errors

    utility_validate_status "Enable Promethues Metrics."

    az extension add --name aks-preview && true
    az extension remove --name k8s-extension && true

    #Verify that the DaemonSet was deployed properly on the Linux node pools
    #https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#managed-prometheus
    kubectl get ds ama-metrics-node --namespace=kube-system
    #if the deployment fails, $?=1.
    utility_validate_status "Validate promethues metrics is enabled."
}

# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration
function deploy_customize_scraping(){
    # https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration?tabs=CRDConfig%2CCRDScrapeConfig#basic-authentication
    local wlsPswBase64=$(echo -n "${WLS_ADMIN_PASSWORD}" | base64)
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ama-metrics-mtls-secret
  namespace: kube-system
type: Opaque
data:
  password1: ${wlsPswBase64}
EOF

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
    password_file: /etc/prometheus/certs/password1
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
        echo_stdout "well tested monitoring exporter image url: ${imageURL}"
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
                                    "values": [
                                        "invocationTotalCount",
                                        "reloadTotal",
                                        "executionTimeAverage",
                                        "poolMaxCapacity",
                                        "executionTimeTotal",
                                        "reloadTotalCount",
                                        "executionTimeHigh",
                                        "executionTimeLow"
                                    ]
                                },
                                "type": "WebAppComponentRuntime",
                                "values": [
                                    "deploymentState",
                                    "contextRoot",
                                    "sourceInfo",
                                    "openSessionsHighCount",
                                    "openSessionsCurrentCount",
                                    "sessionsOpenedTotalCount",
                                    "sessionCookieMaxAgeSecs",
                                    "sessionInvalidationIntervalSecs",
                                    "sessionTimeoutSecs",
                                    "singleThreadedServletPoolSize",
                                    "sessionIDLength",
                                    "servletReloadCheckSecs",
                                    "jSPPageCheckSecs"
                                ]
                            },
                            "workManagerRuntimes": {
                                "prefix": "workmanager_",
                                "key": "applicationName",
                                "values": [
                                    "pendingRequests", 
                                    "completedRequests", 
                                    "stuckThreadCount"]
                            },
                            "key": "name",
                            "keyName": "app"
                        },
                        "JVMRuntime": {
                            "key": "name",
                            "values": [
                                "heapFreeCurrent", 
                                "heapFreePercent", 
                                "heapSizeCurrent", 
                                "heapSizeMax", 
                                "uptime", 
                                "processCpuLoad"
                            ]
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

        local podCount=$(kubectl get pods -n ${KEDA_NAMESPACE} -o json | jq -r '.items | length')
        if [ $podCount -lt 3 ];then
            ready=false
        fi

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

    echo_stderr "KEDA is running." 
}

function get_keda_latest_version() {
    local kedaVersion
    kedaVersion=$(helm search repo kedacore/keda --versions | awk '/^kedacore\/keda/ {print $2; exit}')
    export KEDA_VERSION="${kedaVersion}"
    echo_stderr "Use latest KEDA. KEDA version: ${KEDA_VERSION}"
}


function get_keda_version() {
    local versionJsonFileName="aks_tooling_well_tested_version.json"
    local kedaWellTestedVersion

    # Download the version JSON file
    curl -L "${gitUrl4AksToolingWellTestedVersionJsonFile}" --retry "${retryMaxAttempt}" -o "${versionJsonFileName}"   

    # Extract KEDA version from JSON
    kedaWellTestedVersion=$(jq -r '.items[] | select(.key == "keda") | .version' "${versionJsonFileName}")

    # Check if version is available
    if [ $? -ne 0 ]; then
        get_keda_latest_version
        return 0
    fi

    # Print KEDA well-tested version
    echo_stderr "KEDA well-tested version: ${kedaWellTestedVersion}"

    # Search for KEDA version in Helm repo
    if ! helm search repo kedacore/keda --versions | grep -q "${kedaWellTestedVersion}"; then
        get_keda_latest_version
        return 0
    fi

    # Export KEDA version
    export KEDA_VERSION="${kedaWellTestedVersion}"
    echo_stderr "KEDA version: ${KEDA_VERSION}"
}

# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/integrate-keda
function enable_keda_addon() {
    local oidcEnabled=$(az aks show --resource-group $AKS_CLUSTER_RG_NAME --name $AKS_CLUSTER_NAME --query oidcIssuerProfile.enabled)
    local workloadIdentity=$(az aks show --resource-group $AKS_CLUSTER_RG_NAME --name $AKS_CLUSTER_NAME --query securityProfile.workloadIdentity)

    if [[ "${oidcEnabled,,}" == "false" || -z "${workloadIdentity}" ]]; then
        # mitigate https://github.com/Azure/azure-cli/issues/28649
        pip install --upgrade azure-core
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
        --identity-name $KEDA_UAMI_NAME \
        --resource-group $CURRENT_RG_NAME \
        --issuer $OIDC_ISSUER_URL \
        --subject system:serviceaccount:$KEDA_NAMESPACE:$KEDA_SERVICE_ACCOUNT_NAME \
        --audience api://AzureADTokenExchange
    utility_validate_status "Create keda federated-credential ${kedaFederatedName}."

    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update

    get_keda_version

    helm install keda kedacore/keda \
        --namespace ${KEDA_NAMESPACE} \
        --set serviceAccount.operator.create=false \
        --set serviceAccount.operator.name=${KEDA_SERVICE_ACCOUNT_NAME} \
        --set podIdentity.azureWorkload.enabled=true \
        --set podIdentity.azureWorkload.clientId=$KEDA_UAMI_CLIENT_ID \
        --set podIdentity.azureWorkload.tenantId=$tenantId \
        --set app.kubernetes.io/managed-by=Helm \
        --set meta.helm.sh/release-name=keda \
        --set meta.helm.sh/release-namespace=${KEDA_NAMESPACE} \
        --version ${KEDA_VERSION}

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

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RG_NAME

get_wls_monitoring_exporter_image_url

deploy_webLogic_monitoring_exporter

enable_promethues_metrics

deploy_customize_scraping

enable_keda_addon

output
