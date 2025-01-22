/* 
 Copyright (c) 2021, 2025 Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

// This script is to update existing keyvault with access policy for global uami.
// And enable template deployment for the keyvault.

param keyVault object
param principalId string

var obj_permission = {
  secrets: [
    'get'
    'list'
  ]
}

resource updateKeyvaultStoringWLSSSLCerts 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = {
  name: keyVault.name
  location: keyVault.location
  sku: keyVault.sku
  properties: {
    accessPolicies: [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: obj_permission
      }
    ]
    enabledForTemplateDeployment: true
    enableRbacAuthorization: false
  }
}
