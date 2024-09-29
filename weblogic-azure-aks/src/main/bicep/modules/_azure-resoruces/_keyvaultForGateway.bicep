// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
// Deploy Application Gateway certificate secrets.

@description('Backend certificate data to store in the secret')
param backendCertificateDataValue string = newGuid()

@description('Certificate data to store in the secret')
param certificateDataValue string = newGuid()

@secure()
@description('Certificate password to store in the secret')
param certificatePasswordValue string = newGuid()

@description('true to upload trusted root certificate')
param enableCustomSSL bool = false

@description('Property to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

param identity object = {}
param location string
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
param subjectName string = ''

@description('If false, will create a certificate.')
param useExistingAppGatewaySSLCertificate bool = false

@description('Current deployment time. Used as a tag in deployment script.')
param keyVaultName string = 'GEN_UNIQUE'

@description('${label.tagsLabel}')
param tagsByResource object

var name_sslBackendCertSercretName= 'myAppGatewaySSLBackendRootCert'
var name_sslCertSecretName = 'myAppGatewaySSLCert'
var name_sslCertPasswordSecretName = 'myAppGatewaySSLCertPassword'

module keyVaultwithSelfSignedAppGatewaySSLCert '_keyvault/_keyvaultWithNewCert.bicep' = if (!useExistingAppGatewaySSLCertificate) {
  name: 'kv-appgw-selfsigned-certificate-deployment'
  params: {
    identity: identity
    keyVaultName: keyVaultName
    location: location
    permission: permission
    subjectName: subjectName
    sku: sku
    tagsByResource: tagsByResource
  }
}

module keyVaultwithExistingAppGatewaySSLCert '_keyvault/_keyvaultWithExistingCert.bicep' = if (useExistingAppGatewaySSLCertificate) {
  name: 'kv-appgw-existing-certificate-deployment'
  params: {
    certificateDataName: name_sslCertSecretName
    certificateDataValue: certificateDataValue
    certificatePswSecretName: name_sslCertPasswordSecretName
    certificatePasswordValue: certificatePasswordValue
    enabledForTemplateDeployment: enabledForTemplateDeployment
    keyVaultName: keyVaultName
    location: location
    sku: sku
    tagsByResource: tagsByResource
  }
}

module keyvaultBackendRootCert '_keyvault/_keyvaultForGatewayBackendCert.bicep' = if (enableCustomSSL) {
  name: 'kv-appgw-e2e-ssl-backend-certificate'
  params:{
    certificateDataName: name_sslBackendCertSercretName
    certificateDataValue: backendCertificateDataValue
    enabledForTemplateDeployment: enabledForTemplateDeployment
    keyVaultName: keyVaultName
    location: location
    sku: sku
    tagsByResource: tagsByResource
  }
  dependsOn:[
    keyVaultwithSelfSignedAppGatewaySSLCert
    keyVaultwithExistingAppGatewaySSLCert
  ]
}

output keyVaultName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithExistingAppGatewaySSLCert.outputs.keyVaultName : keyVaultwithSelfSignedAppGatewaySSLCert.outputs.keyVaultName)
output sslCertDataSecretName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithExistingAppGatewaySSLCert.outputs.sslCertDataSecretName : keyVaultwithSelfSignedAppGatewaySSLCert.outputs.secretName)
output sslCertPwdSecretName string = (useExistingAppGatewaySSLCertificate ? keyVaultwithExistingAppGatewaySSLCert.outputs.sslCertPwdSecretName: '')
output sslBackendCertDataSecretName string = (enableCustomSSL) ? keyvaultBackendRootCert.outputs.sslBackendCertDataSecretName : ''

