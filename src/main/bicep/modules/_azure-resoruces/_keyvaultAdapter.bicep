// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('Certificate data to store in the secret')
param certificateDataValue string

@description('Certificate password to store in the secret')
param certificatePasswordValue string

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

param identity object
param permission object = {
  certificates: [
    'get'
    'list'
    'update'
    'create'
  ]
}

@description('Price tier for Key Vault.')
param sku string = 'Standard'

@description('Subject name to create a certificate.')
param subjectName string

@description('If false, will create a certificate.')
param useExistingAppGatewaySSLCertificate bool = false

@description('Current deployment time. Used as a tag in deployment script.')
param keyVaultName string = 'GEN_UNIQUE'

var name_kvWithExistingCertTemplateName = '_keyvaultWithExistingCertTemplate.json'
var name_kvWithNewCertTemplateName = '_keyvaultWithNewCertTemplate.json'
var name_kvTempaltesFolder = '_keyvault'
var name_sslCertSecretName = 'myAppGatewaySSLCert'
var name_sslCertPasswordSecretName = 'myAppGatewaySSLCertPassword'

module keyVaultwithSelfSignedAppGatewaySSLCert '_keyvault/_keyvaultWithNewCert.bicep' = if (!useExistingAppGatewaySSLCertificate) {
  name: 'kv-appgw-selfsigned-certificate-deployment'
  params: {
    identity: identity
    keyVaultName: keyVaultName
    permission: permission
    subjectName: subjectName
    sku: sku
  }
}

module keyVaultwithExistingAppGatewaySSLCert '_keyvault/_keyvaultWithExistingCert.bicep' = if (useExistingAppGatewaySSLCertificate) {
  name: 'kv-appgw-existing-certificate-deployment'
  params: {
    certificateDataName: name_sslCertSecretName
    certificateDataValue: certificateDataValue
    certificatePasswordName: name_sslCertPasswordSecretName
    certificatePasswordValue: certificatePasswordValue
    enabledForTemplateDeployment: enabledForTemplateDeployment
    name: keyVaultName
    sku: sku
  }
}

output keyVaultName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithSelfSignedAppGatewaySSLCert.outputs.keyVaultName : keyVaultwithSelfSignedAppGatewaySSLCert.outputs.keyVaultName)
output sslCertDataSecretName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithExistingAppGatewaySSLCert.outputs.sslCertDataSecretName : keyVaultwithSelfSignedAppGatewaySSLCert.outputs.secretName)
output sslCertPwdSecretName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithExistingAppGatewaySSLCert.outputs.sslCertPwdSecretName: '')
