// Copyright (c) 2022, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param subnetId string
param knownIP string

param identity object
param location string
param utcValue string = utcNow()

var const_azcliVersion='2.15.0'
var const_deploymentName='ds-query-private-ip'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    scriptContent: format('{0}\r\n\r\n{1}', loadTextContent('../../../arm/scripts/common.sh'), loadTextContent('../../../arm/scripts/inline-scripts/queryPrivateIPForAppGateway.sh'))
    environmentVariables: [
      {
        name: 'SUBNET_ID'
        value: subnetId
      }
      {
        name: 'KNOWN_IP'
        value: knownIP
      }
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output privateIP string = string(reference(const_deploymentName).outputs.privateIP)
