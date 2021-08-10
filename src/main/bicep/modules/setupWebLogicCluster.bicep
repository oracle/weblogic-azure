// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

/*
* The script is to create a simple WLS cluster, including:
* Create Azure resources:
*  - Azure Kubenetes Cluster Service instance
*  - Azure Container Registry instance
*  - Azure Storage Account and file share
*  - Azure Container Insight
* Initialize WebLogic cluster:
*  - Build WebLogic domain image and push to ACR.
*  - Install WebLogic Operator
*  - Create WebLogic cluster and make sure the servers are running
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _pidEnd string
param _pidStart string
@description('true to use resource or workspace permissions. false to require workspace permissions.')
param aciResourcePermissions bool = true
@description('Number of days to retain data in Azure Monitor workspace.')
param aciRetentionInDays int = 120
@description('Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
param aciWorkspaceSku string = 'pergb2018'
param acrName string = ''
@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
@description('The number of nodes that should be created along with the cluster. You will be able to resize the cluster later.')
param aksAgentPoolNodeCount int = 3
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param aksAgentPoolVMSize string = 'Standard_DS2_v2'
@description('Prefix for cluster name. Only The name can contain only letters, numbers, underscores and hyphens. The name must start with letter or number.')
param aksClusterNamePrefix string = 'wlsonaks'
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = ''
@description('Name of an existing AKS cluster.')
param aksClusterName string = ''
@description('The AKS version.')
param aksVersion string = 'default'
@description('Urls of Java EE application packages.')
param appPackageUrls array = []
@description('The number of managed server to start.')
param appReplicas int = 2
@description('true to create a new Azure Container Registry.')
param createACR bool = false
@description('true to create a new AKS cluster.')
param createAKSCluster bool = true
param createStorageAccount bool = false
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('true to create persistent volume using file share.')
param enableCustomSSL bool = false
param enablePV bool = false
@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object
param location string = 'eastus'
@description('Name prefix of managed server.')
param managedServerPrefix string = 'managed-server'
@secure()
@description('Password of Oracle SSO account.')
param ocrSSOPSW string
@description('User name of Oracle SSO account.')
param ocrSSOUser string
param storageAccountName string
@secure()
@description('Password for model WebLogic Deploy Tooling runtime encrytion.')
param wdtRuntimePassword string
@description('Maximum cluster size.')
param wlsClusterSize int = 5
@description('Requests for CPU resources for admin server and managed server.')
param wlsCPU string = '200m'
@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsIdentityKeyStoreData string = newGuid()
@secure()
param wlsIdentityKeyStorePassphrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsIdentityKeyStoreType string = 'PKCS12'
@description('Docker tag that comes after "container-registry.oracle.com/middleware/weblogic:"')
param wlsImageTag string = '12.2.1.4'
@description('Memory requests for admin server and managed server.')
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
@secure()
param wlsPrivateKeyAlias string = newGuid()
@secure()
param wlsPrivateKeyPassPhrase string = newGuid()
@secure()
param wlsTrustKeyStoreData string = newGuid()
@secure()
param wlsTrustKeyStorePassPhrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsTrustKeyStoreType string = 'PKCS12'
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'
/*
* Deploy a pid to tract an offer deployment starts
*/
module pidStart './_pids/_pid.bicep' = {
  name: 'wls-aks-start-pid-deployment'
  params: {
    name: _pidStart
  }
}

/*
* Deploy AKS cluster
*/
module aksClusterDeployment './_azure-resoruces/_aks.bicep' = if (createAKSCluster) {
  name: 'aks-cluster-deployment'
  params: {
    aciResourcePermissions: aciResourcePermissions
    aciRetentionInDays: aciRetentionInDays
    aciWorkspaceSku: aciWorkspaceSku
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolVMSize: aksAgentPoolVMSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksVersion: aksVersion
    enableAzureMonitoring: enableAzureMonitoring
    location: location
  }
  dependsOn: [
    pidStart
  ]
}

/*
* Deploy ACR
*/
module acrDeployment './_azure-resoruces/_acr.bicep' = if (createACR) {
  name: 'acr-deployment'
  params: {
    location: location
  }
  dependsOn: [
    pidStart
  ]
}

// enableAppGWIngress: if true, will create storage for certificates.
module storageDeployment './_azure-resoruces/_storage.bicep' = if (createStorageAccount) {
  name: 'storage-deployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
  dependsOn: [
    pidStart
  ]
}

/*
* Deploy WLS domain
*/
module wlsDomainDeployment './_deployment-scripts/_ds-create-wls-cluster.bicep' = {
  name: 'wls-domain-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterRGName: createAKSCluster ? resourceGroup().name : aksClusterRGName
    aksClusterName: createAKSCluster ? aksClusterDeployment.outputs.aksClusterName : aksClusterName
    acrName: createACR ? acrDeployment.outputs.acrName : acrName
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    enableCustomSSL: enableCustomSSL
    enablePV: enablePV
    identity: identity
    location: location
    managedServerPrefix: managedServerPrefix
    storageAccountName: storageAccountName
    ocrSSOUser: ocrSSOUser
    ocrSSOPSW: ocrSSOPSW
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: wlsIdentityKeyStoreData
    wlsIdentityKeyStorePassphrase: wlsIdentityKeyStorePassphrase
    wlsIdentityKeyStoreType: wlsIdentityKeyStoreType
    wlsImageTag: wlsImageTag
    wlsMemory: wlsMemory
    wlsPassword: wlsPassword
    wlsPrivateKeyAlias: wlsPrivateKeyAlias
    wlsPrivateKeyPassPhrase: wlsPrivateKeyPassPhrase
    wlsTrustKeyStoreData: wlsTrustKeyStoreData
    wlsTrustKeyStorePassPhrase: wlsTrustKeyStorePassPhrase
    wlsTrustKeyStoreType: wlsTrustKeyStoreType
    wlsUserName: wlsUserName
  }
  dependsOn: [
    aksClusterDeployment
    acrDeployment
    storageDeployment
  ]
}

/*
* Deploy a pid to tract an offer deployment ends
* Make sure all the dependencies added to dependsOn array
*/
module pidEnd './_pids/_pid.bicep' = {
  name: 'wls-aks-end-pid-deployment'
  params: {
    name: _pidEnd
  }
  dependsOn: [
    wlsDomainDeployment
  ]
}

output aksClusterName string = createAKSCluster ? aksClusterDeployment.outputs.aksClusterName : aksClusterName
output aksClusterRGName string = createAKSCluster ? resourceGroup().name : aksClusterRGName
output adminServerUrl string = format('http://{0}-admin-server.{0}-ns.svc.cluster.local:7001/console', wlsDomainUID)
output clusterSVCUrl string = format('http://{0}-cluster-cluster-1.{0}-ns.svc.cluster.local:8001/', wlsDomainUID)
