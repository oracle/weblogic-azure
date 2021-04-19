@maxLength(12)
@minLength(1)
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
param aksAgentPoolNodeCount int = 3
param aksAgentPoolVMSize string = 'Standard_DS2_v2'
param aksClusterNamePrefix string = 'wlsonaks'
param aksVersion string = 'default'
param location string = 'eastus'

/*
 * Deploy AKS cluster
*/
module AKSClusterDeployment './modules/aks.bicep' = {
  name: 'aksDeploy'
  params: {
    aksAgentPoolName: '${aksAgentPoolName}'
    aksAgentPoolNodeCount: int('${aksAgentPoolNodeCount}')
    aksAgentPoolVMSize: '${aksAgentPoolVMSize}'
    aksClusterNamePrefix: '${aksClusterNamePrefix}'
    aksVersion: '${aksVersion}'
    location: '${location}'
  }
}

output aksClusterName string = AKSClusterDeployment.outputs.aksClusterName
