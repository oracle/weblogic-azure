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

param location string = 'eastus'

param utcValue string = utcNow()

var aciWorkspaceName = 'Workspace-${guid(utcValue)}-${location}'
var aciDisableOmsAgent = {
  enabled: false
}
var aciEnableOmsAgent = {
  enabled: true
  config: {
    logAnalyticsWorkspaceResourceID: azureMonitoringWorkspace.id
  }
}
var aksAgentPoolOSDiskSizeGB = 128
var aksAgentPoolMaxPods = 110
var aksAvailabilityZones = [
  '1'
  '2'
  '3'
]
// Generate a unique AKS name scoped to subscription. 
// Create different cluster name for different deployment to avoid template validation error.
var aksClusterNameDefault = '${aksClusterNamePrefix}0${uniqueString(utcValue)}'
var aksClusterNameForSV = '${aksClusterNamePrefix}1${uniqueString(utcValue)}'

resource azureMonitoringWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = if (enableAzureMonitoring) {
  name: aciWorkspaceName
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
  name: aksClusterNameDefault
  location: location
  properties: {
    dnsPrefix: '${aksClusterNameDefault}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        osDiskSizeGB: aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: aksAgentPoolMaxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: aksAvailabilityZones
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
      omsAgent: enableAzureMonitoring ? aciEnableOmsAgent : aciDisableOmsAgent
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
  name: aksClusterNameForSV
  location: location
  properties: {
    kubernetesVersion: '${aksVersion}'
    dnsPrefix: '${aksClusterNameForSV}-dns'
    agentPoolProfiles: [
      {
        name: aksAgentPoolName
        count: aksAgentPoolNodeCount
        vmSize: aksAgentPoolVMSize
        osDiskSizeGB: aksAgentPoolOSDiskSizeGB
        osDiskType: 'Managed'
        kubeletDiskType: 'OS'
        maxPods: aksAgentPoolMaxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: aksAvailabilityZones
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

output aksClusterName string = '${aksVersion}' == 'default' ? aksClusterNameDefault : aksClusterNameForSV
