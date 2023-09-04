/* 
* Copyright (c) 2021, Oracle Corporation and/or its affiliates.
* Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*
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
*   Replace the partner center pid in mainTemplate.bicep, then run the following command to generate the ARM package, and upload it to partner center.
*   If using azure-javaee-iaas-parent less than 1.0.13, use:
*     $ mvn -Pbicep -Passembly -Ddev clean install
*   otherwise, use
*     $ mvn -Pbicep-dev -Passembly clean install
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
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
@description('The number of nodes that should be created along with the cluster. You will be able to resize the cluster later.')
param aksAgentPoolNodeCount int = 3
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param vmSize string = 'Standard_B8ms'
@description('Prefix for cluster name. Only The name can contain only letters, numbers, underscores and hyphens. The name must start with letter or number.')
param aksClusterNamePrefix string = 'wlsonaks'
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = 'aks-contoso-rg'
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('Name of an existing AKS cluster.')
param aksClusterName string = 'aks-contoso'
@description('The AKS version.')
param aksVersion string = 'default'
@description('true to create a new AKS cluster.')
param createAKSCluster bool = true
param location string
@description('True to use latest supported Kubernetes version.')
param useLatestSupportedAksVersion bool = true
@description('vz cli download uri')
param vzCliDownload string = 'https://github.com/verrazzano/verrazzano/releases/download/v1.6.5/verrazzano-1.6.5-linux-amd64.tar.gz'

// To mitigate arm-ttk error: Type Mismatch: Parameter in nested template is defined as string, but the parent template defines it as bool.
var const_azcliVersion = '2.41.0'
var const_hasTags = contains(resourceGroup(), 'tags')

module uamiDeployment 'modules/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
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
    aksAgentPoolVMSize: vmSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksVersion: aksVersion
    enableAzureMonitoring: enableAzureMonitoring
    location: location
  }
  dependsOn: [
  ]
}

/*
* Deploy AKS cluster
*/
module vzDeployment './modules/_deployment-scripts/_ds-create-vz.bicep' {
  name: 'aks-cluster-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    vzCliDownload: vzCliDownload
    location: location
  }
  dependsOn: [
    aksClusterDeployment
  ]
}

output aksClusterName string = createAKSCluster ? aksClusterDeployment.outputs.aksClusterName : aksClusterName
output aksClusterRGName string = createAKSCluster ? resourceGroup().name : aksClusterRGName
