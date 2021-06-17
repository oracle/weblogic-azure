// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

/* 
* Terms:
* aci is short for Azure Container Insight
* aks is short for Azure Kubernetes Service
* acr is short for Azure Container Registry
*
* Run the template:
*   $ bicep build mainTemplate.bicep
*   $ az deployment group create -f mainTemplate.json -g <rg-name>
*
* Build marketplace offer for test:
*   $ mvn -Pbicep -Ddev -Passembly clean install
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
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
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('true to create persistent volume using file share.')
param enableAzureFileShare bool = false
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
@description('ture to upload Java EE applications and deploy the applications to WebLogic domain.')
param uploadAppPackage bool = false
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
@description('Docker tag that comes after "container-registry.oracle.com/middleware/weblogic:"')
param wlsImageTag string = '12.2.1.4'
@description('Memory requests for admin server and managed server.')
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var name_defaultPidDeployment = 'pid'

/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

module wlsDomainDeployment 'modules/setupWebLogicCluster.bicep' = {
  name: 'setup-wls-cluster'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.wlsAKSEnd == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSEnd
    _pidStart: pids.outputs.wlsAKSStart == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSStart
    aciResourcePermissions: aciResourcePermissions
    aciRetentionInDays: aciRetentionInDays
    aciWorkspaceSku: aciWorkspaceSku
    acrName: acrName
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolVMSize: aksAgentPoolVMSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: aksVersion
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    createACR: createACR
    createAKSCluster: createAKSCluster
    enableAzureMonitoring: enableAzureMonitoring
    enableAzureFileShare: enableAzureFileShare
    identity: identity
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    uploadAppPackage: uploadAppPackage
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsImageTag: wlsImageTag
    wlsMemory: wlsMemory
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
}

output aksClusterName string = wlsDomainDeployment.outputs.aksClusterName
output adminServerUrl string = wlsDomainDeployment.outputs.adminServerUrl
output clusterSVCUrl string = wlsDomainDeployment.outputs.clusterSVCUrl
