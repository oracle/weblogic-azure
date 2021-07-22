# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function cleanup_vm() {
    #Remove VM resources
    az extension add --name resource-graph
    # query vm id
    vmId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${currentResourceGroup}' \
| project vmid = id" -o tsv)

    # query nic id
    nicId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${currentResourceGroup}' \
| extend nics=array_length(properties.networkProfile.networkInterfaces) \
| mv-expand nic=properties.networkProfile.networkInterfaces \
| where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic) \
| project nicId = tostring(nic.id)" -o tsv)

    # query ip id
    ipId=$(az graph query -q "Resources \
| where type =~ 'microsoft.network/networkinterfaces' \
| where id=~ '${nicId}' \
| extend ipConfigsCount=array_length(properties.ipConfigurations) \
| mv-expand ipconfig=properties.ipConfigurations \
| where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true' \
| project  publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" -o tsv)

    # query os disk id
    osDiskId=$(az graph query -q "Resources \
| where type =~ 'microsoft.compute/virtualmachines' \
| where name=~ '${vmName}' \
| where resourceGroup  =~ '${currentResourceGroup}' \
| project osDiskId = tostring(properties.storageProfile.osDisk.managedDisk.id)" -o tsv)

    # query vnet id
    vnetId=$(az graph query -q "Resources \
| where type =~ 'Microsoft.Network/virtualNetworks' \
| where name=~ '${vmName}VNET' \
| where resourceGroup  =~ '${currentResourceGroup}' \
| project vNetId = id" -o tsv)

    # query nsg id
    nsgId=$(az graph query -q "Resources \
| where type =~ 'Microsoft.Network/networkSecurityGroups' \
| where name=~ '${vmName}NSG' \
| where resourceGroup  =~ '${currentResourceGroup}' \
| project nsgId = id" -o tsv)

    # Delete VM NIC IP VNET NSG resoruces
    vmResourceIdS=$(echo ${vmId} ${nicId} ${ipId} ${osDiskId} ${vnetId} ${nsgId})
    echo ${vmResourceIdS}
    az resource delete --verbose --ids ${vmResourceIdS}
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
    # Specify tag 'SkipNRMS*' to skip Microsoft internal NRMS policy, which cause vm-redeployed issue
    az vm create \
    --resource-group ${currentResourceGroup} \
    --name ${vmName} \
    --image "Canonical:UbuntuServer:18.04-LTS:latest" \
    --admin-username azureuser \
    --generate-ssh-keys \
    --nsg-rule NONE \
    --enable-agent true \
    --vnet-name ${vmName}VNET \
    --enable-auto-update false \
    --tags SkipASMAzSecPack=true SkipNRMSCorp=true SkipNRMSDatabricks=true SkipNRMSDB=true SkipNRMSHigh=true SkipNRMSMedium=true SkipNRMSRDPSSH=true SkipNRMSSAW=true SkipNRMSMgmt=true --verbose

    wlsImagePath="${ocrLoginServer}/middleware/weblogic:${wlsImageTag}"
    az vm extension set --name CustomScript \
    --extension-instance-name wls-image-script \
    --resource-group ${currentResourceGroup} \
    --vm-name ${vmName} \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --settings "{ \"fileUris\": [\"${scriptURL}model.properties\",\"${scriptURL}genImageModel.sh\",\"${scriptURL}buildWLSDockerImage.sh\",\"${scriptURL}common.sh\"]}" \
    --protected-settings "{\"commandToExecute\":\"bash buildWLSDockerImage.sh ${wlsImagePath} ${azureACRServer} ${azureACRUserName} ${azureACRPassword} ${newImageTag} \\\"${appPackageUrls}\\\" ${ocrSSOUser} ${ocrSSOPSW} ${wlsClusterSize} ${enableCustomSSL} \"}"

    #Validate image from ACR
    az acr repository show -n ${acrName} --image aks-wls-images:${newImageTag}

    cleanup_vm
}

# Shell Global settings
set -e #Exit immediately if a command exits with a non-zero status.

export currentResourceGroup=$1
export wlsImageTag=$2
export azureACRServer=$3
export azureACRUserName=$4
export azureACRPassword=$5
export newImageTag=$6
export appPackageUrls=$7
export ocrSSOUser=$8
export ocrSSOPSW=$9
export wlsClusterSize=${10}
export enableCustomSSL=${11}
export scriptURL=${12}

echo ${scriptURL}

build_docker_image



