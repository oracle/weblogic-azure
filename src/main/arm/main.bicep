/* 
* Terms
* aci is short for Azure Container Insight
* aks is short for Azure Kubernetes Service
*
* Run the template:
*   $ bicep build main.bicep
*   $ az deployment group create -f main.json -g <rg-name>
*/

@description('true to use resource or workspace permissions. false to require workspace permissions.')
param aciResourcePermissions bool = true

@description('Number of days to retain data in Azure Monitor workspace.')
param aciRetentionInDays int = 120

@description('Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
param aciWorkspaceSku string = 'pergb2018'

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

param aksVersion string = 'default'

@description('true to create a new AKS cluster.')
param createAKSCluster bool = true

@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false

param location string = 'eastus'

/*
 * Deploy AKS cluster
*/
module AKSClusterDeployment './modules/aks.bicep' = if(createAKSCluster){
  name: 'aksDeploy'
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
}

output aksClusterName string = AKSClusterDeployment.outputs.aksClusterName
