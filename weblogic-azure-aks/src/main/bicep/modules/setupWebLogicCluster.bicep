// Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
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
param _pidEnd string = 'pid-wls-end'
param _pidStart string = 'pid-wls-start'
param _pidSSLEnd string = 'pid-ssl-end'
param _pidSSLStart string = 'pid-ssl-start'
param _globalResourceNameSuffix string
@description('true to use resource or workspace permissions. false to require workspace permissions.')
param aciResourcePermissions bool = true
@description('Number of days to retain data in Azure Monitor workspace.')
param aciRetentionInDays int = 120
@description('Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
param aciWorkspaceSku string = 'pergb2018'
param acrName string = ''
param acrResourceGroupName string = ''
param aksAgentAvailabilityZones array = []
@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'nodepool1'
@maxValue(10000)
@minValue(1)
@description('Set the minimum node count for the cluster..')
param aksAgentPoolNodeCount int = 3
@maxValue(1000)
@minValue(3)
@description('Set the maximum node count for the cluster.')
param aksAgentPoolNodeMaxCount int = 5
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param vmSize string = 'Standard_DS2_v2'
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
param azCliVersion string = ''
param cpuPlatform string = 'linux/amd64'
@description('true to create a new AKS cluster.')
param createAKSCluster bool = true
param databaseType string = 'oracle'
param dbDriverLibrariesUrls array = []
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('true to create persistent volume using file share.')
param enableCustomSSL bool = false
param enableAdminT3Tunneling bool = false
param enableClusterT3Tunneling bool = false
param enablePswlessConnection bool = false
param enablePV bool = false
param fileShareName string = ''
@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object = {}
param isSSOSupportEntitled bool
param location string
@description('Name prefix of managed server.')
param managedServerPrefix string = 'managed-server'
@secure()
@description('Password of Oracle SSO account.')
param ocrSSOPSW string
@description('User name of Oracle SSO account.')
param ocrSSOUser string
param storageAccountName string = 'stg-contoso'
param t3ChannelAdminPort int = 7005
param t3ChannelClusterPort int = 8011
@description('Tags for the resources')
param tagsByResource object
param userProvidedAcr string = 'null'
param userProvidedAcrRgName string = 'null'
param userProvidedImagePath string = 'null'
param useOracleImage bool = true
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
param wlsJavaOption string = 'null'
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

module pidSSLStart './_pids/_pid.bicep' = if (enableCustomSSL) {
  name: 'wls-ssl-start-pid-deployment'
  params: {
    name: _pidSSLStart
  }
}

resource existingAKSCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' existing = if (!createAKSCluster) {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
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
    agentAvailabilityZones: aksAgentAvailabilityZones
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolNodeMaxCount: aksAgentPoolNodeMaxCount
    aksAgentPoolVMSize: vmSize
    aksClusterName: aksClusterName
    aksVersion: aksVersion
    enableAzureMonitoring: enableAzureMonitoring
    location: location
    tagsByResource: tagsByResource
  }
  dependsOn: [
    pidStart
  ]
}

// enableAppGWIngress: if true, will create storage for certificates.
module storageDeployment './_azure-resoruces/_storage.bicep' = {
  name: 'storage-deployment'
  params: {
    fileShareName: fileShareName
    location: location
    storageAccountName: storageAccountName
    tagsByResource: tagsByResource
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
    _globalResourceNameSuffix: _globalResourceNameSuffix
    aksAgentPoolName: aksAgentPoolName
    aksClusterRGName: createAKSCluster ? resourceGroup().name : aksClusterRGName
    aksClusterName: aksClusterName
    acrName: useOracleImage ? acrName : userProvidedAcr
    acrResourceGroupName: useOracleImage ? acrResourceGroupName : userProvidedAcrRgName
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    azCliVersion: azCliVersion
    cpuPlatform: cpuPlatform
    databaseType: databaseType
    dbDriverLibrariesUrls: dbDriverLibrariesUrls
    enableCustomSSL: enableCustomSSL
    enableAdminT3Tunneling: enableAdminT3Tunneling
    enableClusterT3Tunneling: enableClusterT3Tunneling
    enablePswlessConnection: enablePswlessConnection
    enablePV: enablePV
    fileShareName: fileShareName
    identity: identity
    isSSOSupportEntitled: isSSOSupportEntitled
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOUser: ocrSSOUser
    ocrSSOPSW: ocrSSOPSW
    storageAccountName: storageAccountName
    t3ChannelAdminPort: t3ChannelAdminPort
    t3ChannelClusterPort: t3ChannelClusterPort
    tagsByResource: tagsByResource
    userProvidedImagePath: userProvidedImagePath
    useOracleImage: useOracleImage
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: wlsIdentityKeyStoreData
    wlsIdentityKeyStorePassphrase: wlsIdentityKeyStorePassphrase
    wlsIdentityKeyStoreType: wlsIdentityKeyStoreType
    wlsImageTag: wlsImageTag
    wlsJavaOption: wlsJavaOption
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
    storageDeployment
  ]
}

module pidSSLEnd './_pids/_pid.bicep' = if (enableCustomSSL) {
  name: 'wls-ssl-end-pid-deployment'
  params: {
    name: _pidSSLEnd
  }
  dependsOn: [
    wlsDomainDeployment
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

output aksClusterName string = aksClusterName
output aksClusterRGName string = createAKSCluster ? resourceGroup().name : aksClusterRGName
output aksNodeRgName string = createAKSCluster? aksClusterDeployment.outputs.aksNodeRgName : existingAKSCluster.properties.nodeResourceGroup
output adminServerEndPoint string = format('http://{0}-admin-server.{0}-ns.svc.cluster.local:7001/console', wlsDomainUID)
output adminServerT3InternalEndPoint string = enableAdminT3Tunneling ? format('{0}://{1}-admin-server.{1}-ns.svc.cluster.local:{2}', enableCustomSSL ? 't3s' : 't3', wlsDomainUID, t3ChannelAdminPort): ''
output clusterEndPoint string = format('http://{0}-cluster-cluster-1.{0}-ns.svc.cluster.local:8001/', wlsDomainUID)
output clusterT3InternalEndPoint string = enableClusterT3Tunneling ? format('{0}://{1}-cluster-cluster-1.{1}-ns.svc.cluster.local:{2}', enableCustomSSL ? 't3s' : 't3', wlsDomainUID, t3ChannelClusterPort): ''
