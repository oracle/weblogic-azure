// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true
@description('Name of the vault')
param keyVaultName string
@description('Price tier for Key Vault.')
param sku string
param wlsIdentityKeyStoreData string
param wlsIdentityKeyStoreDataSecretName string
@secure()
param wlsIdentityKeyStorePassphrase string
param wlsIdentityKeyStorePassphraseSecretName string
param wlsPrivateKeyAlias string
param wlsPrivateKeyAliasSecretName string
@secure()
param wlsPrivateKeyPassPhrase string
param wlsPrivateKeyPassPhraseSecretName string
param wlsTrustKeyStoreData string
param wlsTrustKeyStoreDataSecretName string
@secure()
param wlsTrustKeyStorePassPhrase string
param wlsTrustKeyStorePassPhraseSecretName string

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    enabledForTemplateDeployment: enabledForTemplateDeployment
    sku: {
      name: sku
      family: 'A'
    }
    accessPolicies: []
    tenantId: subscription().tenantId
  }
}

resource identityKeyStoreDataSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsIdentityKeyStoreDataSecretName}'
  properties: {
    value: wlsIdentityKeyStoreData
  }
  dependsOn: [
    keyvault
  ]
}

resource identityKeyStorePswSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsIdentityKeyStorePassphraseSecretName}'
  properties: {
    value: wlsIdentityKeyStorePassphrase
  }
  dependsOn: [
    keyvault
  ]
}

resource privateKeyAliasSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsPrivateKeyAliasSecretName}'
  properties: {
    value: wlsPrivateKeyAlias
  }
  dependsOn: [
    keyvault
  ]
}

resource privateKeyPswSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsPrivateKeyPassPhraseSecretName}'
  properties: {
    value: wlsPrivateKeyPassPhrase
  }
  dependsOn: [
    keyvault
  ]
}

resource trustKeyStoreDataSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsTrustKeyStoreDataSecretName}'
  properties: {
    value: wlsTrustKeyStoreData
  }
  dependsOn: [
    keyvault
  ]
}

resource trustKeyStorePswSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${wlsTrustKeyStorePassPhraseSecretName}'
  properties: {
    value: wlsTrustKeyStorePassPhrase
  }
  dependsOn: [
    keyvault
  ]
}

