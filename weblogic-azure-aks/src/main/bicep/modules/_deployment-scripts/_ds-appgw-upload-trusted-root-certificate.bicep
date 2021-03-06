// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param appgwName string = 'appgw-contoso'
param azCliVersion string = ''
@secure()
param sslBackendRootCertData string = newGuid()
param identity object = {}
param location string
param utcValue string = utcNow()

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_uploadAppGatewayTrutedRootCert=loadFileAsBase64('../../../arm/scripts/uploadAppGatewayTrutedRootCert.sh')
var const_arguments = '${resourceGroup().name} ${appgwName} ${sslBackendRootCertData}'
var const_deploymentName='ds-upload-trusted-root-certificatre-to-gateway'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    arguments: const_arguments
    scriptContent: base64ToString(base64_uploadAppGatewayTrutedRootCert)
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
