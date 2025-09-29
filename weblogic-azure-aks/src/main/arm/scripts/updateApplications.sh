# Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

function usage() {
    usage=$(cat <<-END
Specify the following ENV variables:
ACR_NAME
AKS_CLUSTER_NAME
AKS_CLUSTER_RESOURCEGROUP_NAME
CURRENT_RESOURCEGROUP_NAME
ORACLE_ACCOUNT_NAME
ORACLE_ACCOUNT_SHIBBOLETH
STORAGE_ACCOUNT_NAME
STORAGE_ACCOUNT_CONTAINER_NAME
SCRIPT_LOCATION
USE_ORACLE_IMAGE
USER_PROVIDED_IMAGE_PATH
WLS_APP_PACKAGE_URLS
WLS_DOMAIN_NAME
WLS_DOMAIN_UID
WLS_IMAGE_TAG
END
)
    echo_stdout "${usage}"
    if [ $1 -eq 1 ]; then
        echo_stderr "${usage}"
        exit 1
    fi
}

#Function to validate input
function validate_input() {
    if [ -z "$USE_ORACLE_IMAGE" ]; then
        echo_stderr "USER_PROVIDED_IMAGE_PATH is required. "
        usage 1
    fi

    if [[ "${USE_ORACLE_IMAGE,,}" == "${constTrue}" ]] && [[ -z "$ORACLE_ACCOUNT_NAME" || -z "${ORACLE_ACCOUNT_SHIBBOLETH}" ]]; then
        echo_stderr "Oracle SSO account is required. "
        usage 1
    fi

    if [[ -z "$AKS_CLUSTER_RESOURCEGROUP_NAME" || -z "${AKS_CLUSTER_NAME}" ]]; then
        echo_stderr "AKS cluster name and resource group name are required. "
        usage 1
    fi

    if [ -z "$WLS_IMAGE_TAG" ]; then
        echo_stderr "WLS_IMAGE_TAG is required. "
        usage 1
    fi

    if [ -z "$ACR_NAME" ]; then
        echo_stderr "ACR_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_DOMAIN_NAME" ]; then
        echo_stderr "WLS_DOMAIN_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_DOMAIN_UID" ]; then
        echo_stderr "WLS_DOMAIN_UID is required. "
        usage 1
    fi

    if [ -z "$CURRENT_RESOURCEGROUP_NAME" ]; then
        echo_stderr "CURRENT_RESOURCEGROUP_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_APP_PACKAGE_URLS" ]; then
        echo_stderr "WLS_APP_PACKAGE_URLS is required. "
        usage 1
    fi

    if [ -z "$SCRIPT_LOCATION" ]; then
        echo_stderr "SCRIPT_LOCATION is required. "
        usage 1
    fi

    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
        echo_stderr "STORAGE_ACCOUNT_NAME is required. "
        usage 1
    fi

    if [ -z "$STORAGE_ACCOUNT_CONTAINER_NAME" ]; then
        echo_stderr "STORAGE_ACCOUNT_CONTAINER_NAME is required. "
        usage 1
    fi

    if [[ "${USE_ORACLE_IMAGE,,}" == "${constFalse}" ]] && [ -z "$USER_PROVIDED_IMAGE_PATH" ]; then
        echo_stderr "USER_PROVIDED_IMAGE_PATH is required. "
        usage 1
    fi
}

function query_wls_cluster_info(){
    WLS_CLUSTER_SIZE=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json \
        | jq '. | .status.clusters[] | select(.clusterName == "'${constClusterName}'") | .maximumReplicas')
    echo "cluster size: ${WLS_CLUSTER_SIZE}"
    
    ENABLE_CUSTOM_SSL=${constFalse}
    sslIdentityEnv=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${sslIdentityEnvName}'")')
    if [ -n "${sslIdentityEnv}" ]; then
        ENABLE_CUSTOM_SSL=${constTrue}
    fi
}

# Query ACR login server, username, password
function query_acr_credentials() {
    echo "query credentials of ACR ${ACR_NAME}"
    ACR_LOGIN_SERVER=$(az acr show -n $ACR_NAME --query 'loginServer' -o tsv)
    ACR_USER_NAME=$(az acr credential show -n $ACR_NAME --query 'username' -o tsv)
    ACR_SHIBBOLETH=$(az acr credential show -n $ACR_NAME --query 'passwords[0].value' -o tsv)
}

function get_app_sas_url() {
    args=("$@")
    appNumber=$#
    index=0
    appSASUrlString=""
    while [ $index -lt $appNumber ]; do
        appName=${args[${index}]}
        echo "app package file name: ${appName}"
        if [[ "$appName" == *".war" || "$appName" == *".ear" || "$appName" == *".jar" ]]; then
            appSaSUrl=$(az storage blob url --container-name ${STORAGE_ACCOUNT_CONTAINER_NAME} \
                --name ${appName} \
                --account-name ${STORAGE_ACCOUNT_NAME} \
                --sas-token ${sasToken} -o tsv)
            echo ${appSaSUrl}
            appSASUrlString="${appSASUrlString},${appSaSUrl}"
        fi

        index=$((index+1))
    done

    # append urls
    if [ "${WLS_APP_PACKAGE_URLS}" == "[]" ]; then
        WLS_APP_PACKAGE_URLS="[${appSASUrlString:1:${#appSASUrlString}-1}]" # remove the beginning comma
    else
        WLS_APP_PACKAGE_URLS=$(echo "${WLS_APP_PACKAGE_URLS:1:${#WLS_APP_PACKAGE_URLS}-2}") # remove []
        WLS_APP_PACKAGE_URLS="[${WLS_APP_PACKAGE_URLS}${appSASUrlString}]"
    fi

    echo $WLS_APP_PACKAGE_URLS
}

function query_app_urls() {
    echo "check if the storage account exists."
    ret=$(az storage account check-name --name ${STORAGE_ACCOUNT_NAME} \
        | grep "AlreadyExists")
    if [ -z "$ret" ]; then
        echo "${STORAGE_ACCOUNT_NAME} does not exist."
        return
    fi

    appList=$(az storage blob list --container-name ${STORAGE_ACCOUNT_CONTAINER_NAME} \
        --account-name ${STORAGE_ACCOUNT_NAME} \
        | jq '.[] | .name' \
        | tr -d "\"")

    if [ $? == 1 ]; then
        echo "Failed to query application from ${STORAGE_ACCOUNT_CONTAINER_NAME}"
        return
    fi

    expiryData=$(( `date +%s`+${sasTokenValidTime}))
    sasTokenEnd=`date -d@"$expiryData" -u '+%Y-%m-%dT%H:%MZ'`
    sasToken=$(az storage account generate-sas \
        --permissions r \
        --account-name ${STORAGE_ACCOUNT_NAME} \
        --services b \
        --resource-types sco \
        --expiry $sasTokenEnd -o tsv)
    
    get_app_sas_url ${appList}
}

function build_docker_image() {
    local adminT3AddressEnv=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${constAdminT3AddressEnvName}'")')
    if [ -n "${adminT3AddressEnv}" ]; then
        ENABLE_ADMIN_CUSTOM_T3=${constTrue}
    fi

    local clusterT3AddressEnv=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${constClusterT3AddressEnvName}'")')
    if [ -n "${clusterT3AddressEnv}" ]; then
        ENABLE_CLUSTER_CUSTOM_T3=${constTrue}
    fi

    export WLS_APP_PACKAGE_URLS=$(echo $WLS_APP_PACKAGE_URLS | base64 -w0)
    echo "build a new image including the new applications"
    chmod ugo+x $scriptDir/createVMAndBuildImage.sh
    echo ${ACR_SHIBBOLETH} \
        | bash $scriptDir/createVMAndBuildImage.sh $newImageTag ${ACR_LOGIN_SERVER} ${ACR_USER_NAME}

    az acr repository show -n ${ACR_NAME} --image aks-wls-images:${newImageTag}
    if [ $? -ne 0 ]; then
        echo "Failed to create image ${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}"
        exit 1
    fi
}

function apply_new_image() {
    acrImagePath="${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}"
    restartVersion=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} '-o=jsonpath={.spec.restartVersion}')
    # increase restart version
    restartVersion=$((restartVersion + 1))
    kubectl -n ${wlsDomainNS} patch domain ${WLS_DOMAIN_UID} \
        --type=json \
        '-p=[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/image", "value": "'${acrImagePath}'" }]'
}

function wait_for_pod_completed() {
    # Make sure all of the pods are running.
    local clusterName=$(kubectl get cluster -n ${wlsDomainNS} -o json | jq -r '.items[0].metadata.name')
    local replicas=$(kubectl -n ${wlsDomainNS} get cluster ${clusterName} -o json \
        | jq '. | .spec.replicas')

    utility_wait_for_pod_completed \
        ${replicas} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    local clusterName=$(kubectl get cluster -n ${wlsDomainNS} -o json | jq -r '.items[0].metadata.name')
    local replicas=$(kubectl -n ${wlsDomainNS} get cluster ${clusterName} -o json \
        | jq '. | .spec.replicas')
    
    utility_wait_for_image_update_completed \
        "${acrImagePath}" \
        ${replicas} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

#Output value to deployment scripts
function output_image() {
  echo ${acrImagePath}

  result=$(jq -n -c \
    --arg image $acrImagePath \
    '{image: $image}')
  echo "output of deployment script: $result"
  echo $result >$AZ_SCRIPTS_OUTPUT_PATH
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

export newImageTag=$(date +%s)
# seconds
export sasTokenValidTime=3600
export sslIdentityEnvName="SSL_IDENTITY_PRIVATE_KEY_ALIAS"
export wlsDomainNS="${WLS_DOMAIN_UID}-ns"

# export ENV var that will be used in createVMAndBuildImage.sh
export ENABLE_ADMIN_CUSTOM_T3=${constFalse}
export ENABLE_CLUSTER_CUSTOM_T3=${constFalse}
export ENABLE_CUSTOM_SSL=${constFalse}
export WLS_CLUSTER_SIZE=5
export URL_3RD_DATASOURCE=$(echo "[]" | base64)

# Main script
set -Eo pipefail

validate_input

install_kubectl

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RESOURCEGROUP_NAME

query_wls_cluster_info

query_acr_credentials

query_app_urls

build_docker_image

apply_new_image

wait_for_image_update_completed

wait_for_pod_completed

output_image
