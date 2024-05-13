// Copyright (c) 2024, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aksClusterName string 
param aksClusterRGName string
param azCliVersion string
@allowed([
  'cpu'
  'memory'
])
param hpaScaleType string = 'cpu'
param identity object = {}
param location string
param utcValue string = utcNow()
param utilizationPercentage int
param wlsClusterSize int
param wlsNamespace string

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_common = loadFileAsBase64('../../../arm/scripts/common.sh')
var base64_enableHpa = loadFileAsBase64('../../../arm/scripts/inline-scripts/enableHpa.sh')
var base64_utility = loadFileAsBase64('../../../arm/scripts/utility.sh')
var const_deploymentName='ds-enable-hpa'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    scriptContent: format('{0}\r\n\r\n{1}\r\n\r\n{2}',base64ToString(base64_common), base64ToString(base64_utility), base64ToString(base64_enableHpa))
    environmentVariables: [
      {
        name: 'AKS_CLUSTER_RG_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'CURRENT_RG_NAME'
        value: resourceGroup().name
      }
      {
        name: 'HPA_SCALE_TYPE'
        value: hpaScaleType
      }
      {
        name: 'UTILIZATION_PERCENTAGE'
        value: utilizationPercentage
      }
      {
        name: 'WLS_CLUSTER_SIZE'
        value: wlsClusterSize
      }
      {
        name: 'WLS_NAMESPACE'
        value: wlsNamespace
      }
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
