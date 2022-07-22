// Copyright (c) 2022, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aksClusterName string 
param aksClusterRGName string
param appgwName string = 'appgw-contoso'
param azCliVersion string = ''
param identity object = {}
param location string
param utcValue string = utcNow()

var const_deploymentName='ds-validate-agic'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    scriptContent: format('{0}\r\n\r\n{1}\r\n\r\n{2}',loadTextContent('../../../arm/scripts/common.sh'), loadTextContent('../../../arm/scripts/utility.sh'), loadTextContent('../../../arm/scripts/inline-scripts/enableAgic.sh'))
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
        name: 'APPGW_NAME'
        value: appgwName
      }
      {
        name: 'CURRENT_RG_NAME'
        value: resourceGroup().name
      }
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
