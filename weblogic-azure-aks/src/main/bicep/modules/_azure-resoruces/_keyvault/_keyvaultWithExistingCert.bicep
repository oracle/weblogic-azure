// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('Secret name of certificate data.')
param certificateDataName string = 'myIdentityKeyStoreData'

@description('Certificate data to store in the secret')
param certificateDataValue string = newGuid()

@description('Secret name of certificate password.')
param certificatePswSecretName string = 'myIdentityKeyStorePsw'

@secure()
@description('Certificate password to store in the secret')
param certificatePasswordValue string = newGuid()

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

@description('Name of the vault')
param keyVaultName string = 'kv-contoso'

param location string

@description('Price tier for Key Vault.')
param sku string = 'Standard'

@description('${label.tagsLabel}')
param tagsByResource object

param utcValue string = utcNow()

var obj_extraTag= {
  'created-by-azure-weblogic': utcValue
}

resource keyvault 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = {
  name: keyVaultName
  location: location
  properties: {
    accessPolicies: []
    enabledForTemplateDeployment: enabledForTemplateDeployment
    sku: {
      name: sku
      family: 'A'
    }
    tenantId: subscription().tenantId
  }
  tags: union(tagsByResource['${identifier.vaults}'], obj_extraTag)
}

resource secretForCertificate 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVault}' = {
  name: '${keyVaultName}/${certificateDataName}'
  properties: {
    value: certificateDataValue
  }
  tags: union(tagsByResource['${identifier.vaults}'], obj_extraTag)
  dependsOn: [
    keyvault
  ]
}

resource secretForCertPassword 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${certificatePswSecretName}'
  properties: {
    value: certificatePasswordValue
  }
  tags: union(tagsByResource['${identifier.vaults}'], obj_extraTag)
  dependsOn: [
    keyvault
  ]
}

output keyVaultName string = keyVaultName
output sslCertDataSecretName string = certificateDataName
output sslCertPwdSecretName string = certificatePswSecretName
