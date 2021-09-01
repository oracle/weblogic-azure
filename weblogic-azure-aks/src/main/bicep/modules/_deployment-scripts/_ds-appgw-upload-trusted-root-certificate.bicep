// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param appgwName string
@secure()
param sslBackendRootCertData string = newGuid()
param identity object
param utcValue string = utcNow()

var const_arguments = '${resourceGroup().name} ${appgwName} ${sslBackendRootCertData}'
var const_azcliVersion='2.15.0'
var const_deploymentName='ds-upload-trusted-root-certificatre-to-gateway'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    arguments: const_arguments
    scriptContent: loadTextContent('../../../arm/scripts/uploadAppGatewayTrutedRootCert.sh')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
