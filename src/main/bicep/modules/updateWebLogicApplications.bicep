/* 
Copyright (c) 2018, 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
 
Description
  - This script is to update applications running in an existing WebLogic Cluster.
  - Application input can be customized using parameters appPackageUrls and appPackageFromStorageBlob.

Pre-requisites
  - There is at least one WebLogic cluster running on Azure Kubernetes Service (AKS), the cluster must be deployed using Azure WebLoigc on AKS marketplace offer.
  - Azure CLI with bicep installed.

Parameters
  - _artifactsLocation: Script location.
  - acrName: Name of Azure Container Registry that is used to managed the WebLogic domain images.
  - aksClusterRGName: Name of resource group that contains the (AKS) instance, probably the resource group you are working on. It's recommended to run this sript with the same resource group that runs AKS.
  - aksClusterName: Name of the AKS instance that runs the WebLogic cluster.
  - appPackageUrls: String array of Java EE applciation location, which can be downloaded using "curl". Currently, only support urls of Azure Storage Account blob.
  - appPackageFromStorageBlob: Storage blob that contains Java EE applciations, the script will download all the .war and .ear file from that blob. Do not include white space in the file name.
    - storageAccountName: Storage account name.
    - containerName: container name.
  - identity: Azure user managed identity used, make sure the identity has permission to create/update/delete Azure resources. It's recommended to assign "Contributor" role.
  - ocrSSOPSW: Password of Oracle SSO account. The script will pull image from Oracle Container Registry (OCR), Oracle account is required. Make sure the account has checkout WebLogic images.
  - ocrSSOUser: User name of Oracle SSO account.
  - wlsDomainName: Name of the domain that you are going to update. Make sure it's the same with the initial cluster deployment.
  - wlsDomainUID: UID of the domain that you are going to update. Make sure it's the same with the initial cluster deployment.
  - wlsImageTag: The available WebLogic docker image tags that OCR provides.

Build and run
  - Run command `bicep build updateWebLogicApplications.bicep`, you will get built ARM template updateWebLogicApplications.json.
  - Prepare parameters file parameters.json
  - Run command `az deployment group create -f updateWebLogicApplications.json -p parameters.json -g <your-resource-group>`
*/

param _artifactsLocation string = ''
@secure()
param _artifactsLocationSasToken string = ''

param acrName string = ''
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = ''
@description('Name of an existing AKS cluster.')
param aksClusterName string = ''

@description('Download all the .war and .ear packages from the specified storage blob. You can specify the applciation using "appPackageUrls" and "appPackageFromStorageBlob", please do not specify the same applciation in both parameters.')
param appPackageFromStorageBlob object = {
  storageAccountName: 'stg-contoso'
  containerName: 'container-contoso'
}
@description('Url array of Java EE application locations.')
param appPackageUrls array = []

param identity object

@secure()
@description('Password of Oracle SSO account.')
param ocrSSOPSW string
@description('User name of Oracle SSO account.')
param ocrSSOUser string

@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@description('Docker tag that comes after "container-registry.oracle.com/middleware/weblogic:"')
param wlsImageTag string = '12.2.1.4'

module pids './_pids/_pid.bicep' = {
  name: 'initialization'
}

module pidStart './_pids/_pid.bicep' = {
  name: 'wls-aks-update-app-start-pid-deployment'
  params: {
    name: pids.outputs.wlsClusterAppStart
  }
  dependsOn:[
    pids
  ]
}

module updateWLSApplications '_deployment-scripts/_ds_update-applications.bicep' = {
  name: 'update-wls-applications'
  params:{
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    acrName: acrName
    appPackageUrls: appPackageUrls
    appPackageFromStorageBlob: appPackageFromStorageBlob
    identity: identity
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsImageTag: wlsImageTag
  }
  dependsOn:[
    pidStart
  ]
}


module pidEnd './_pids/_pid.bicep' = {
  name: 'wls-aks-update-app-end-pid-deployment'
  params: {
    name: pids.outputs.wlsClusterAppEnd
  }
  dependsOn:[
    updateWLSApplications
  ]
}

output image string = updateWLSApplications.outputs.image
