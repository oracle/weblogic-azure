// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true
@description('Name of the vault')
param keyVaultName string
param location string
@description('Price tier for Key Vault.')
param sku string = 'Standard'
@description('${label.tagsLabel}')
param tagsByResource object
param utcValue string = utcNow()
@secure()
param wlsIdentityKeyStoreData string = newGuid()
param wlsIdentityKeyStoreDataSecretName string = 'myIdentityKeyStoreData'
@secure()
param wlsIdentityKeyStorePassphrase string = newGuid()
param wlsIdentityKeyStorePassphraseSecretName string = 'myIdentityKeyStorePsw'
@secure()
param wlsPrivateKeyAlias string = newGuid()
param wlsPrivateKeyAliasSecretName string = 'privateKeyAlias'
@secure()
param wlsPrivateKeyPassPhrase string = newGuid()
param wlsPrivateKeyPassPhraseSecretName string = 'privateKeyPsw'
@secure()
param wlsTrustKeyStoreData string = newGuid()
param wlsTrustKeyStoreDataSecretName string = 'myTrustKeyStoreData'
@secure()
param wlsTrustKeyStorePassPhrase string = newGuid()
param wlsTrustKeyStorePassPhraseSecretName string = 'myTrustKeyStorePsw'

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
  tags: union(tagsByResource['${identifier.vaults}'],obj_extraTag)
}

resource identityKeyStoreDataSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsIdentityKeyStoreDataSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsIdentityKeyStoreData
  }
  dependsOn: [
    keyvault
  ]
}

resource identityKeyStorePswSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsIdentityKeyStorePassphraseSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsIdentityKeyStorePassphrase
  }
  dependsOn: [
    keyvault
  ]
}

resource privateKeyAliasSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsPrivateKeyAliasSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsPrivateKeyAlias
  }
  dependsOn: [
    keyvault
  ]
}

resource privateKeyPswSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsPrivateKeyPassPhraseSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsPrivateKeyPassPhrase
  }
  dependsOn: [
    keyvault
  ]
}

resource trustKeyStoreDataSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsTrustKeyStoreDataSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsTrustKeyStoreData
  }
  dependsOn: [
    keyvault
  ]
}

resource trustKeyStorePswSecret 'Microsoft.KeyVault/vaults/secrets@${azure.apiVersionForKeyVaultSecrets}' = {
  name: '${keyVaultName}/${wlsTrustKeyStorePassPhraseSecretName}'
  tags: tagsByResource['${identifier.vaults}']
  properties: {
    value: wlsTrustKeyStorePassPhrase
  }
  dependsOn: [
    keyvault
  ]
}
