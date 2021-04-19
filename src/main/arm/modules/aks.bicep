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

var aksAgentPoolOSDiskSizeGB = 128
var aksAgentPoolMaxPods = 110
var aksAvailabilityZones = [
  '1'
  '2'
  '3'
]
// Generate a unique AKS name scoped to subscription. 
// Create different cluster name for different deployment to avoid template validation error.
var aksClusterNameDefault = concat(aksClusterNamePrefix, '0', uniqueString(subscription().subscriptionId))
var aksClusterNameForSV = concat(aksClusterNamePrefix, '1', uniqueString(subscription().subscriptionId))
var AKSAPIVersion = '2021-02-01'

resource aksClusterLatest 'Microsoft.ContainerService/managedClusters@2021-02-01' = if (contains(aksVersion, 'default')) {
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
      omsAgent: {
        enabled: false
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
        enabled: false
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
