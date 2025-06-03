// Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('true to use resource or workspace permissions. false to require workspace permissions.')
param aciResourcePermissions bool = true
@description('Number of days to retain data in Azure Monitor workspace.')
param aciRetentionInDays int = 120
@description('Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
param aciWorkspaceSku string = 'pergb2018'
param agentAvailabilityZones array = []
@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'nodepool1'
@maxValue(10000)
@minValue(1)
@description('The number of nodes that should be created along with the cluster. You will be able to resize the cluster later.')
param aksAgentPoolNodeCount int = 3
param aksAgentPoolNodeMaxCount int = 5
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param aksAgentPoolVMSize string = 'Standard_DS2_v2'
@description('Prefix for cluster name. Only The name can contain only letters, numbers, underscores and hyphens. The name must start with letter or number.')
param aksClusterName string
param aksVersion string = 'default'
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
param location string
@description('Tags for the resources')
param tagsByResource object
param utcValue string = utcNow()

var const_aksAgentPoolOSDiskSizeGB = 128
var name_aciWorkspace = 'Workspace-${guid(utcValue)}-${location}'
// Generate a unique AKS name scoped to subscription. 
var obj_aciDisableOmsAgent = {
  enabled: false
}
var obj_aciEnableOmsAgent = {
  enabled: true
  config: {
    logAnalyticsWorkspaceResourceID: azureMonitoringWorkspace.id
  }
}

resource azureMonitoringWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableAzureMonitoring) {
  name: name_aciWorkspace
  location: location
  tags: tagsByResource['Microsoft.OperationalInsights/workspaces']
  properties: {
    sku: {
      name: aciWorkspaceSku
    }
    retentionInDays: aciRetentionInDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: aciResourcePermissions
    }
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' = {
  name: aksClusterName
  location: location
  tags: tagsByResource['Microsoft.ContainerService/managedClusters']
  properties: {
    kubernetesVersion: aksVersion
    dnsPrefix: '${aksClusterName}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        enableAutoScaling: true
        minCount: aksAgentPoolNodeCount
        maxCount: aksAgentPoolNodeMaxCount
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        osDiskSizeGB: const_aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        type: 'VirtualMachineScaleSets'
        availabilityZones: agentAvailabilityZones
        mode: 'System'
        osType: 'Linux'
        tags: tagsByResource['Microsoft.ContainerService/managedClusters']
      }
    ]
    addonProfiles: {
      KubeDashboard: {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      httpApplicationRouting: {
        enabled: false
      }
      omsAgent: enableAzureMonitoring ? obj_aciEnableOmsAgent : obj_aciDisableOmsAgent
    }
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
  identity: {
    // enable system identity.
    type: 'SystemAssigned'
  }
}

output aksNodeRgName string = aksCluster.properties.nodeResourceGroup
