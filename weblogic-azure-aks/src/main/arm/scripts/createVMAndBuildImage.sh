# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# env inputs:
# URL_3RD_DATASOURCE
# ORACLE_ACCOUNT_ENTITLED

echo "Script  ${0} starts"

# read <acrPassword> from stdin
function read_sensitive_parameters_from_stdin() {
    read acrPassword
}

function cleanup_vm() {
    echo "deleting vm resources..."
    #Remove VM resources
    az extension add --name resource-graph
    # query vm id
    vmId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${CURRENT_RESOURCEGROUP_NAME}' \
| project vmid = id" --query "data[0].vmid"  -o tsv)

    # query nic id
    nicId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${CURRENT_RESOURCEGROUP_NAME}' \
| extend nics=array_length(properties.networkProfile.networkInterfaces) \
| mv-expand nic=properties.networkProfile.networkInterfaces \
| where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic) \
| project nicId = tostring(nic.id)" --query "data[0].nicId" -o tsv)

    # query ip id
    ipId=$(az graph query -q "Resources \
| where type =~ 'microsoft.network/networkinterfaces' \
| where id=~ '${nicId}' \
| extend ipConfigsCount=array_length(properties.ipConfigurations) \
| mv-expand ipconfig=properties.ipConfigurations \
| where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true' \
| project  publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" --query "data[0].publicIpId" -o tsv)

    # query os disk id
    osDiskId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${CURRENT_RESOURCEGROUP_NAME}' \
| project osDiskId = tostring(properties.storageProfile.osDisk.managedDisk.id)" --query "data[0].osDiskId" -o tsv)

    # query vnet id
    vnetId=$(az graph query -q "Resources \
| where type =~ 'Microsoft.Network/virtualNetworks' \
| where name=~ '${vmName}VNET' \
| where resourceGroup  =~ '${CURRENT_RESOURCEGROUP_NAME}' \
| project vNetId = id" --query "data[0].vNetId" -o tsv)

    # query nsg id
    nsgId=$(az graph query -q "Resources \
| where type =~ 'Microsoft.Network/networkSecurityGroups' \
| where name=~ '${vmName}NSG' \
| where resourceGroup  =~ '${CURRENT_RESOURCEGROUP_NAME}' \
| project nsgId = id" --query "data[0].nsgId" -o tsv)

    # Delete VM NIC IP VNET NSG resoruces
    echo "deleting vm ${vmId}"
    az vm delete --ids $vmId --yes
    echo "deleting nic ${nicId}"
    az network nic delete --ids ${nicId}
    echo "deleting public-ip ${ipId}"
    az network public-ip delete --ids ${ipId}
    echo "deleting disk ${osDiskId}"
    az disk delete --yes --ids ${osDiskId}
    echo "deleting vnet ${vnetId}"
    az network vnet delete --ids ${vnetId}
    echo "deleting nsg ${nsgId}"
    az network nsg delete --ids ${nsgId}
}

# generate image full path based on the oracle account
function get_ocr_image_full_path() {
  local ocrImageFullPath="${ocrLoginServer}/${ocrGaImagePath}:${WLS_IMAGE_TAG}"

  if [[ "${ORACLE_ACCOUNT_ENTITLED,,}" == "true" ]]; then

    # download the ga cpu image mapping file.
    local cpuImagesListFile=weblogic_cpu_images.json
    curl -L ${gitUrl4CpuImages} --retry ${retryMaxAttempt} -o ${cpuImagesListFile}
    local cpuTag=$(cat ${cpuImagesListFile} | jq ".items[] | select(.gaTag==\"${WLS_IMAGE_TAG}\") | .cpuTag" | tr -d "\"")
    # if we can not find a matched image, keep the tag name the same as GA tag.
    if [[ "${cpuTag}" == "" ||  "${cpuTag,,}" == "null" ]]; then
      cpuTag=${WLS_IMAGE_TAG}
    fi

    ocrImageFullPath="${ocrLoginServer}/${ocrCpuImagePath}:${cpuTag}"
  fi

  wlsImagePath=${ocrImageFullPath}
}

# Build docker image
#  * Create Ubuntu machine VM-UBUNTU
#  * Running vm extension to run buildWLSDockerImage.sh, the script will:
#    * build a docker image with domain model, applications based on specified WebLogic Standard image
#    * push the image to ACR
function build_docker_image() {
    # Create vm to build docker image
    vmName="VM-UBUNTU-WLS-AKS-$(date +%s)"

    # MICROSOFT_INTERNAL
    # Specify tag 'SkipASMAzSecPack' to skip policy 'linuxazuresecuritypackautodeployiaas_1.6'
    # Specify tag 'SkipNRMS*' to skip Microsoft internal NRMS policy, which causes vm-redeployed issue
    az vm create \
    --resource-group ${CURRENT_RESOURCEGROUP_NAME} \
    --name ${vmName} \
    --image "Canonical:UbuntuServer:18.04-LTS:latest" \
    --admin-username azureuser \
    --generate-ssh-keys \
    --nsg-rule NONE \
    --enable-agent true \
    --vnet-name ${vmName}VNET \
    --enable-auto-update false \
    --tags SkipASMAzSecPack=true SkipNRMSCorp=true SkipNRMSDatabricks=true SkipNRMSDB=true SkipNRMSHigh=true SkipNRMSMedium=true SkipNRMSRDPSSH=true SkipNRMSSAW=true SkipNRMSMgmt=true --verbose

    if [[ "${USE_ORACLE_IMAGE,,}" == "${constTrue}" ]]; then
        get_ocr_image_full_path
    else
        wlsImagePath="${USER_PROVIDED_IMAGE_PATH}"
    fi

    echo "wlsImagePath: ${wlsImagePath}"
    URL_3RD_DATASOURCE=$(echo $URL_3RD_DATASOURCE | tr -d "\"") # remove " from the string
    az vm extension set --name CustomScript \
        --extension-instance-name wls-image-script \
        --resource-group ${CURRENT_RESOURCEGROUP_NAME} \
        --vm-name ${vmName} \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --settings "{ \"fileUris\": [\"${SCRIPT_LOCATION}model.properties\",\"${SCRIPT_LOCATION}genImageModel.sh\",\"${SCRIPT_LOCATION}buildWLSDockerImage.sh\",\"${SCRIPT_LOCATION}common.sh\"]}" \
        --protected-settings "{\"commandToExecute\":\"echo ${acrPassword} ${ORACLE_ACCOUNT_PASSWORD} | bash buildWLSDockerImage.sh ${wlsImagePath} ${acrLoginServer} ${acrUser} ${newImageTag} ${WLS_APP_PACKAGE_URLS} ${ORACLE_ACCOUNT_NAME} ${WLS_CLUSTER_SIZE} ${ENABLE_CUSTOM_SSL} ${ENABLE_ADMIN_CUSTOM_T3} ${ENABLE_CLUSTER_CUSTOM_T3} ${USE_ORACLE_IMAGE} ${URL_3RD_DATASOURCE} ${ENABLE_PASSWORDLESS_DB_CONNECTION} ${DB_TYPE} \"}"
    
    cleanup_vm
}

# Shell Global settings
set -Eeo pipefail #Exit immediately if a command exits with a non-zero status.

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh

export newImageTag=$1
export acrLoginServer=$2
export acrUser=$3

read_sensitive_parameters_from_stdin

build_docker_image



