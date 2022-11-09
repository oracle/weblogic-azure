// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aadPodIdentityName string = ''
param aadPodIdentityNameSpace string = ''
param aadPodIdentityResourceId string = ''
param aksClusterRGName string = ''
param aksClusterName string = ''
param azCliVersion string = ''
param identity object = {}
param location string
param utcValue string = utcNow()

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_script = loadFileAsBase64('../../../arm/scripts/inline-scripts/createPodIdentity.sh')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'create-pod-identity'
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
      {
        name: 'POD_IDENTITY_NAME'
        value: aadPodIdentityName
      }
      {
        name: 'POD_IDENTITY_NAMESPACE'
        value: aadPodIdentityNameSpace
      }
      {
        name: 'IDENTITY_RESOURCE_ID'
        value: aadPodIdentityResourceId
      }
    ]
    scriptContent: base64ToString(base64_script)
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output image string = deploymentScript.properties.outputs.image
