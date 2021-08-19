// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aksClusterName string = ''
param aksClusterRGName string = ''

param identity object
param utcValue string = utcNow()
param wlsDomainUID string = 'sample-domain1'

var const_arguments = '${aksClusterRGName} ${aksClusterName} ${wlsDomainUID}'
var const_azcliVersion='2.15.0'
var const_deploymentName='ds-query-storage-account'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    arguments: const_arguments
    scriptContent: loadTextContent('../../../arm/scripts/queryStorageAccount.sh')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output storageAccount string = string(reference(const_deploymentName).outputs.storageAccount)
