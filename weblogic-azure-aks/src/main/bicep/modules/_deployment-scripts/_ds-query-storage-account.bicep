// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aksClusterName string = ''
param aksClusterRGName string = ''
param azCliVersion string = ''

param identity object = {}
param location string
param utcValue string = utcNow()

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_queryStorageAccount = loadFileAsBase64('../../../arm/scripts/queryStorageAccount.sh')
var const_deploymentName = 'ds-query-storage-account'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'AKS_CLUSTER_RESOURCEGROUP_NAME'
        value: aksClusterRGName
      }
    ]
    scriptContent: base64ToString(base64_queryStorageAccount)
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output storageAccount string = string(deploymentScript.properties.outputs.storageAccount)
