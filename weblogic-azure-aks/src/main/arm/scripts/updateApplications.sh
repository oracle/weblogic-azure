# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

# read <ocrSSOPSW> from stdin
function read_sensitive_parameters_from_stdin() {
    read ocrSSOPSW
}

function usage() {
    usage=$(cat <<-END
Usage: 
echo <ocrSSOPSW> | 
    ./updateApplications.sh
    <ocrSSOUser>
    <aksClusterRGName>
    <aksClusterName>
    <wlsImageTag>
    <acrName>
    <wlsDomainName>
    <wlsDomainUID>
    <currentResourceGroup>
    <appPackageUrls>
    <scriptURL>
    <appStorageAccountName>
    <appContainerName>
    <userProvidedImagePath>
    <useOracleImage>
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
    if [ -z "$useOracleImage" ]; then
        echo_stderr "userProvidedImagePath is required. "
        usage 1
    fi

    if [[ "${useOracleImage,,}" == "${constTrue}" ]] && [[ -z "$ocrSSOUser" || -z "${ocrSSOPSW}" ]]; then
        echo_stderr "Oracle SSO account is required. "
        usage 1
    fi

    if [[ -z "$aksClusterRGName" || -z "${aksClusterName}" ]]; then
        echo_stderr "AKS cluster name and resource group name are required. "
        usage 1
    fi

    if [ -z "$wlsImageTag" ]; then
        echo_stderr "wlsImageTag is required. "
        usage 1
    fi

    if [ -z "$acrName" ]; then
        echo_stderr "acrName is required. "
        usage 1
    fi

    if [ -z "$wlsDomainName" ]; then
        echo_stderr "wlsDomainName is required. "
        usage 1
    fi

    if [ -z "$wlsDomainUID" ]; then
        echo_stderr "wlsDomainUID is required. "
        usage 1
    fi

    if [ -z "$currentResourceGroup" ]; then
        echo_stderr "currentResourceGroup is required. "
        usage 1
    fi

    if [ -z "$appPackageUrls" ]; then
        echo_stderr "appPackageUrls is required. "
        usage 1
    fi

    if [ -z "$scriptURL" ]; then
        echo_stderr "scriptURL is required. "
        usage 1
    fi

    if [ -z "$appStorageAccountName" ]; then
        echo_stderr "appStorageAccountName is required. "
        usage 1
    fi

    if [ -z "$appContainerName" ]; then
        echo_stderr "appContainerName is required. "
        usage 1
    fi

    if [[ "${useOracleImage,,}" == "${constFalse}" ]] && [ -z "$userProvidedImagePath" ]; then
        echo_stderr "userProvidedImagePath is required. "
        usage 1
    fi
}

# Connect to AKS cluster
function connect_aks_cluster() {
    az aks get-credentials \
        --resource-group ${aksClusterRGName} \
        --name ${aksClusterName} \
        --overwrite-existing
}

function query_wls_cluster_info(){
    wlsClusterSize=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .status.clusters[] | select(.clusterName == "'${wlsClusterName}'") | .maximumReplicas')
    echo "cluster size: ${wlsClusterSize}"
    
    enableCustomSSL=${constFalse}
    sslIdentityEnv=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${sslIdentityEnvName}'")')
    if [ -n "${sslIdentityEnv}" ]; then
        enableCustomSSL=${constTrue}
    fi
}

# Query ACR login server, username, password
function query_acr_credentials() {
    echo "query credentials of ACR ${acrName}"
    azureACRServer=$(az acr show -n $acrName --query 'loginServer' -o tsv)
    azureACRUserName=$(az acr credential show -n $acrName --query 'username' -o tsv)
    azureACRPassword=$(az acr credential show -n $acrName --query 'passwords[0].value' -o tsv)
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
            appSaSUrl=$(az storage blob url --container-name ${appContainerName} \
                --name ${appName} \
                --account-name ${appStorageAccountName} \
                --sas-token ${sasToken} -o tsv)
            echo ${appSaSUrl}
            appSASUrlString="${appSASUrlString},${appSaSUrl}"
        fi

        index=$((index+1))
    done

    # append urls
    if [ "${appPackageUrls}" == "[]" ]; then
        appPackageUrls="[${appSASUrlString:1:${#appSASUrlString}-1}]" # remove the beginning comma
    else
        appPackageUrls=$(echo "${appPackageUrls:1:${#appPackageUrls}-2}") # remove []
        appPackageUrls="[${appPackageUrls}${appSASUrlString}]"
    fi

    echo $appPackageUrls
}

function query_app_urls() {
    echo "check if the storage account exists."
    ret=$(az storage account check-name --name ${appStorageAccountName} \
        | grep "AlreadyExists")
    if [ -z "$ret" ]; then
        echo "${appStorageAccountName} does not exist."
        return
    fi

    appList=$(az storage blob list --container-name ${appContainerName} \
        --account-name ${appStorageAccountName} \
        | jq '.[] | .name' \
        | tr -d "\"")

    if [ $? == 1 ]; then
        echo "Failed to query application from ${appContainerName}"
        return
    fi

    expiryData=$(( `date +%s`+${sasTokenValidTime}))
    sasTokenEnd=`date -d@"$expiryData" -u '+%Y-%m-%dT%H:%MZ'`
    sasToken=$(az storage account generate-sas \
        --permissions r \
        --account-name ${appStorageAccountName} \
        --services b \
        --resource-types sco \
        --expiry $sasTokenEnd -o tsv)
    
    get_app_sas_url ${appList}
}

function build_docker_image() {
    local enableAdminT3=${constFalse}
    local enableClusterT3=${constFalse}

    local adminT3AddressEnv=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${constAdminT3AddressEnvName}'")')
    if [ -n "${adminT3AddressEnv}" ]; then
        enableAdminT3=${constTrue}
    fi

    local clusterT3AddressEnv=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.serverPod.env[] | select(.name=="'${constClusterT3AddressEnvName}'")')
    if [ -n "${clusterT3AddressEnv}" ]; then
        enableClusterT3=${constTrue}
    fi

    echo "build a new image including the new applications"
    chmod ugo+x $scriptDir/createVMAndBuildImage.sh
    echo $azureACRPassword $ocrSSOPSW | \
        bash $scriptDir/createVMAndBuildImage.sh \
        $currentResourceGroup \
        $wlsImageTag \
        $azureACRServer \
        $azureACRUserName \
        $newImageTag \
        "$appPackageUrls" \
        $ocrSSOUser \
        $wlsClusterSize \
        $enableCustomSSL \
        "$scriptURL" \
        ${enableAdminT3} \
        ${enableClusterT3} \
        ${useOracleImage} \
        ${userProvidedImagePath}

    az acr repository show -n ${acrName} --image aks-wls-images:${newImageTag}
    if [ $? -ne 0 ]; then
        echo "Failed to create image ${azureACRServer}/aks-wls-images:${newImageTag}"
        exit 1
    fi
}

function apply_new_image() {
    acrImagePath="${azureACRServer}/aks-wls-images:${newImageTag}"
    restartVersion=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} '-o=jsonpath={.spec.restartVersion}')
    # increase restart version
    restartVersion=$((restartVersion + 1))
    kubectl -n ${wlsDomainNS} patch domain ${wlsDomainUID} \
        --type=json \
        '-p=[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/image", "value": "'${acrImagePath}'" }]'
}

function wait_for_pod_completed() {
    # Make sure all of the pods are running.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.clusters[] | .replicas')

    utility_wait_for_pod_completed \
        ${replicas} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.clusters[] | .replicas')
    
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

export ocrSSOUser=$1
export aksClusterRGName=$2
export aksClusterName=$3
export wlsImageTag=$4
export acrName=$5
export wlsDomainName=$6
export wlsDomainUID=$7
export currentResourceGroup=$8
export appPackageUrls=$9
export scriptURL=${10}
export appStorageAccountName=${11}
export appContainerName=${12}
export userProvidedImagePath=${13}
export useOracleImage=${14}

export newImageTag=$(date +%s)
# seconds
export sasTokenValidTime=3600
export sslIdentityEnvName="SSL_IDENTITY_PRIVATE_KEY_ALIAS"
export wlsClusterName="cluster-1"
export wlsDomainNS="${wlsDomainUID}-ns"

read_sensitive_parameters_from_stdin

validate_input

install_kubectl

connect_aks_cluster

query_wls_cluster_info

query_acr_credentials

query_app_urls

build_docker_image

apply_new_image

wait_for_image_update_completed

wait_for_pod_completed

output_image
