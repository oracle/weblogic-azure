// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

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
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
param location string = resourceGroup().location
param utcValue string = utcNow()

var const_aksAgentPoolOSDiskSizeGB = 128
var const_aksAgentPoolMaxPods = 110
var const_aksAvailabilityZones = [
  '1'
  '2'
  '3'
]
var name_aciWorkspace = 'Workspace-${guid(utcValue)}-${location}'
// Generate a unique AKS name scoped to subscription. 
// Create different cluster name for different deployment to avoid template validation error.
var name_aksClusterNameDefault = '${aksClusterNamePrefix}0${uniqueString(utcValue)}'
var name_aksClusterNameForSV = '${aksClusterNamePrefix}1${uniqueString(utcValue)}'
var obj_aciDisableOmsAgent = {
  enabled: false
}
var obj_aciEnableOmsAgent = {
  enabled: true
  config: {
    logAnalyticsWorkspaceResourceID: azureMonitoringWorkspace.id
  }
}

resource azureMonitoringWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = if (enableAzureMonitoring) {
  name: name_aciWorkspace
  location: location
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

resource aksClusterDefault 'Microsoft.ContainerService/managedClusters@2021-02-01' = if (contains(aksVersion, 'default')) {
  name: name_aksClusterNameDefault
  location: location
  properties: {
    dnsPrefix: '${name_aksClusterNameDefault}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        osDiskSizeGB: const_aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: const_aksAgentPoolMaxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: const_aksAvailabilityZones
        nodeLabels: {}
        mode: 'System'
        osType: 'Linux'
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
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
  }
  identity: {
    // enable system identity.
    type: 'SystemAssigned'
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2021-02-01' = if (!contains(aksVersion, 'default')) {
  name: name_aksClusterNameForSV
  location: location
  properties: {
    kubernetesVersion: '${aksVersion}'
    dnsPrefix: '${name_aksClusterNameForSV}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        osDiskSizeGB: const_aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: const_aksAgentPoolMaxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: const_aksAvailabilityZones
        nodeLabels: {}
        mode: 'System'
        osType: 'Linux'
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
      omsAgent: {
        enabled: bool('${enableAzureMonitoring}')
      }
    }
    enableRBAC: true
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
  }
  identity: {
    // enable system identity.
    type: 'SystemAssigned'
  }
}

output aksClusterName string = '${aksVersion}' == 'default' ? name_aksClusterNameDefault : name_aksClusterNameForSV
