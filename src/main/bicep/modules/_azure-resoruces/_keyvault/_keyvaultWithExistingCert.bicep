// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('Secret name of certificate data.')
param certificateDataName string

@description('Certificate data to store in the secret')
param certificateDataValue string

@description('Secret name of certificate password.')
param certificatePasswordName string

@description('Certificate password to store in the secret')
param certificatePasswordValue string

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

@description('Name of the vault')
param name string

@description('Price tier for Key Vault.')
param sku string

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: name
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

resource secretForCertificate 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${name}/${certificateDataName}'
  properties: {
    value: certificateDataValue
  }
  dependsOn: [
    keyvault
  ]
}

resource secretForCertPassword 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${name}/${certificatePasswordName}'
  properties: {
    value: certificatePasswordValue
  }
  dependsOn: [
    keyvault
  ]
}

output keyVaultName string = name
output sslCertDataSecretName string = certificateDataName
output sslCertPwdSecretName string = certificatePasswordName
