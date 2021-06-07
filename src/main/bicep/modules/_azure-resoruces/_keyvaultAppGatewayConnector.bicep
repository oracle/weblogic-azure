// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@allowed([
  'haveKeyVault'
  'haveCert'
  'generateCert'
])
@description('Three scenarios we support for deploying app gateway')
param appGatewayCertificateOption string = 'haveCert'

@description('Custom DNS Zone domain name for the Application Gateway')
param customDomainNameforApplicationGateway string = 'application.contoso.xyz'

@description('Azure DNS for Application Gateway')
param domainLabelforApplicationGateway string = 'wlsgw'

@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'

@description('Key Vault name')
param keyVaultName string = ''

@description('Name of resource group in current subscription containing the Key Vault')
param keyVaultResourceGroup string = ''

@description('The name of the secret in the specified Key Vault whose value is the SSL Certificate Data,')
param keyVaultSSLCertDataSecretName string = 'myCertSecretData'

@description('The name of the secret in the specified Key Vault whose value is the password for the SSL Certificate')
param keyVaultSSLCertPasswordSecretName string = ''

var const_appGatewaySSLCertOptionGenerateCert = 'generateCert'
var const_appGatewaySSLCertOptionHaveCert = 'haveCert'
var const_appGatewaySSLCertOptionHaveKeyVault = 'haveKeyVault'
var name_appgwDeployment = 'appgw-${appGatewayCertificateOption}-deployment'

// get key vault object in a resource group
resource existingKeyvault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

module appGatewaywithExistingKeyVault '_appgateway.bicep' = if (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault) {
  name: 'appgw-${const_appGatewaySSLCertOptionHaveKeyVault}-deployment'
  params: {
    appGatewaySSLCertificateData: existingKeyvault.getSecret(keyVaultSSLCertDataSecretName)
    appGatewaySSLCertificatePassword: existingKeyvault.getSecret(keyVaultSSLCertPasswordSecretName)
    dnsNameforApplicationGateway: domainLabelforApplicationGateway
    gatewayPublicIPAddressName: gatewayPublicIPAddressName
  }
}

module appGatewaywithExistingSSLCert '_appgateway.bicep' = if (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveCert) {
  name: 'appgw-${const_appGatewaySSLCertOptionHaveCert}-deployment'
  params: {
    appGatewaySSLCertificateData: existingKeyvault.getSecret(keyVaultSSLCertDataSecretName)
    appGatewaySSLCertificatePassword: existingKeyvault.getSecret(keyVaultSSLCertPasswordSecretName)
    dnsNameforApplicationGateway: domainLabelforApplicationGateway
    gatewayPublicIPAddressName: gatewayPublicIPAddressName
  }
}

module appGatewaywithSelfSignedCert '_appgateway.bicep' = if (appGatewayCertificateOption == const_appGatewaySSLCertOptionGenerateCert) {
  name: 'appgw-${const_appGatewaySSLCertOptionGenerateCert}-deployment'
  params: {
    appGatewaySSLCertificateData: existingKeyvault.getSecret(keyVaultSSLCertDataSecretName)
    appGatewaySSLCertificatePassword: ''
    dnsNameforApplicationGateway: domainLabelforApplicationGateway
    gatewayPublicIPAddressName: gatewayPublicIPAddressName
  }
}

output appGatewayAlias string = reference(name_appgwDeployment).outputs.appGatewayAlias.value
output appGatewayName string = reference(name_appgwDeployment).outputs.appGatewayName.value
output appGatewayURL string = reference(name_appgwDeployment).outputs.appGatewayURL.value
output appGatewaySecuredURL string = reference(name_appgwDeployment).outputs.appGatewaySecuredURL.value
output vnetName string =  reference(name_appgwDeployment).outputs.vnetName.value
