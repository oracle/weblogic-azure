// Copyright (c) 2022, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param azCliVersion string = ''
param subnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param knownIP string = '10.0.0.1'

param identity object = {}
param location string
@description('Tags for the resources')
param tagsByResource object
param utcValue string = utcNow()

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_common = loadFileAsBase64('../../../arm/scripts/common.sh')
var base64_queryPrivateIPForAppGateway = loadFileAsBase64('../../../arm/scripts/inline-scripts/queryPrivateIPForAppGateway.sh')
var const_deploymentName = 'ds-query-private-ip-${uniqueString(utcValue)}'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['Microsoft.Resources/deploymentScripts']
  properties: {
    azCliVersion: azCliVersion
    scriptContent: format('{0}\r\n\r\n{1}', base64ToString(base64_common), base64ToString(base64_queryPrivateIPForAppGateway))
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

output privateIP string = string(deploymentScript.properties.outputs.privateIP)
