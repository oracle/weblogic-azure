# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

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
        if [[ "$appName" == *".war" || "$appName" == *".ear" ]]; then
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
    echo "build a new image including the new applications"
    chmod ugo+x $scriptDir/createVMAndBuildImage.sh
    bash $scriptDir/createVMAndBuildImage.sh \
        $currentResourceGroup \
        $wlsImageTag \
        $azureACRServer \
        $azureACRUserName \
        $azureACRPassword \
        $newImageTag \
        "$appPackageUrls" \
        $ocrSSOUser \
        $ocrSSOPSW \
        $wlsClusterSize \
        $enableCustomSSL \
        "$scriptURL"

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

    echo "Waiting for $((replicas+1)) pods are running."

    readyPodNum=0
    attempt=0
    while [[ ${readyPodNum} -le  ${replicas} && $attempt -le ${checkPodStatusMaxAttemps} ]];do        
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json \
            | jq '.items[] | .status.phase' \
            | grep "Running")
        if [ -z "${ret}" ];then
            readyPodNum=0
        else
            readyPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json \
                | jq '.items[] | .status.phase' \
                | grep -c "Running")
        fi
        echo "Number of new running pod: ${readyPodNum}"
        attempt=$((attempt+1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ];then
        echo "It takes too long to wait for all the pods are running, please refer to http://oracle.github.io/weblogic-kubernetes-operator/samples/simple/azure-kubernetes-service/#troubleshooting"
        exit 1
    fi
}

function wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.clusters[] | .replicas')
    echo "Waiting for $((replicas+1)) new pods created with image ${acrImagePath}"
    
    updatedPodNum=0
    attempt=0
    while [ ${updatedPodNum} -le  ${replicas} ] && [ $attempt -le ${checkPodStatusMaxAttemps} ];do
        echo "attempts ${attempt}"
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json \
            | jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' \
            | grep "${acrImagePath}")
    
        if [ -z "${ret}" ];then
            updatedPodNum=0
        else
            updatedPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json \
                | jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' \
                | grep -c "${acrImagePath}")
        fi
        echo "Number of new pod: ${updatedPodNum}"

        attempt=$((attempt+1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ];then
        echo "Failed to update with image ${acrImagePath} to all weblogic server pods. "
        exit 1
    fi
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
export ocrSSOPSW=$2
export aksClusterRGName=$3
export aksClusterName=$4
export wlsImageTag=$5
export acrName=$6
export wlsDomainName=$7
export wlsDomainUID=$8
export currentResourceGroup=$9
export appPackageUrls=${10}
export scriptURL=${11}
export appStorageAccountName=${12}
export appContainerName=${13}

export newImageTag=$(date +%s)
# seconds
export sasTokenValidTime=3600
export sslIdentityEnvName="SSL_IDENTITY_PRIVATE_KEY_ALIAS"
export wlsClusterName="cluster-1"
export wlsDomainNS="${wlsDomainUID}-ns"

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
