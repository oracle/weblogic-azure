// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _pidAppgwEnd string = 'pid-networking-appgateway-end'
param _pidAppgwStart string = 'pid-networking-appgateway-start'
param _pidAppgwWithCustomCert string = 'pid-networking-appgateway-with-custom-certificate'
param appgwPublicIPAddressName string = 'gwip'
param appgwUsePrivateIP bool
param appgwSslCertName string = 'appGatewaySslCert'
param appgwTrustedRootCertName string = 'appGatewayTrustedRootCert'
param azCliVersion string = ''
param dnsNameforApplicationGateway string = 'wlsgw'
param enableCustomSSL bool
param identity object = {}
param keyVaultName string = 'kv-contoso'
param keyVaultResourceGroup string = 'kv-contoso-rg'
param keyvaultBackendCertDataSecretName string = 'kv-ssl-backend-data'
param keyvaultFrontendCertDataSecretName string = 'kv-ssl-frontend-data'
param keyvaultFrontendCertPswSecretName string = 'kv-ssl-frontend-psw'
param location string
param newOrExistingVnetForApplicationGateway string
param vnetForApplicationGateway object
param vnetRGNameForApplicationGateway string

// To mitigate arm-ttk error: Type Mismatch: Parameter in nested template is defined as string, but the parent template defines it as bool.
var _appgwUsePrivateIP = appgwUsePrivateIP
var _selfSignedFrontendCertAndNoBackendCert = empty(keyvaultFrontendCertPswSecretName) && !enableCustomSSL
var _selfSignedFrontendCertAndBackendCert = empty(keyvaultFrontendCertPswSecretName) && enableCustomSSL
var _signedFrontendCertAndNoBackendCert = !empty(keyvaultFrontendCertPswSecretName) && !enableCustomSSL
var _signedFrontendCertAndBackendCert = !empty(keyvaultFrontendCertPswSecretName) && enableCustomSSL
var const_null = 'null' // To mitigate arm-ttk error: Parameter-Types-Should-Be-Consistent
var name_gatewayDeploymentPrefix = 'app-gateway-deployment-'
var ref_gatewayDeployment = _selfSignedFrontendCertAndNoBackendCert ? appgwDeployment1 : (_selfSignedFrontendCertAndBackendCert ? appgwDeployment2 : _signedFrontendCertAndNoBackendCert ? appgwDeployment3 : appgwDeployment4)

module pidAppgwStart './_pids/_pid.bicep' = {
  name: 'pid-app-gateway-start-deployment'
  params: {
    name: _pidAppgwStart
  }
}
module pidAppgwWithCustomCertificate './_pids/_pid.bicep' = if (_signedFrontendCertAndNoBackendCert || _signedFrontendCertAndBackendCert) {
  name: 'pid-app-gateway-with-custom-certificate'
  params: {
    name: _pidAppgwWithCustomCert
  }
}

// get key vault object from a resource group
resource existingKeyvault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

module networkDeployment '_azure-resoruces/_vnetAppGateway.bicep' = {
  name: 'vnet-application-gateway'
  params: {
    location: location
    vnetForApplicationGateway: vnetForApplicationGateway
  }
  dependsOn: [
    pidAppgwStart
  ]
}

module queryPrivateIPFromSubnet '_deployment-scripts/_ds_query_available_private_ip_from_subnet.bicep' = if (appgwUsePrivateIP) {
  name: 'query-available-private-ip-for-app-gateway'
  params: {
    azCliVersion: azCliVersion
    identity: identity
    location: location
    subnetId: networkDeployment.outputs.subIdForApplicationGateway
    knownIP: networkDeployment.outputs.knownIPAddress
  }
  dependsOn: [
    networkDeployment
  ]
}

module appgwDeployment1 '_azure-resoruces/_appgateway.bicep' = if (_selfSignedFrontendCertAndNoBackendCert) {
  name: '${name_gatewayDeploymentPrefix}1'
  params: {
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    enableCustomSSL: enableCustomSSL
    gatewayPublicIPAddressName: appgwPublicIPAddressName
    gatewaySubnetId: networkDeployment.outputs.subIdForApplicationGateway
    gatewaySslCertName: appgwSslCertName
    gatewayTrustedRootCertName: appgwTrustedRootCertName
    location: location
    noSslCertPsw: true
    sslCertData: existingKeyvault.getSecret(keyvaultFrontendCertDataSecretName)
    sslCertPswData: const_null
    staticPrivateFrontentIP: _appgwUsePrivateIP ? queryPrivateIPFromSubnet.outputs.privateIP : ''
    trustedRootCertData: const_null
    usePrivateIP: appgwUsePrivateIP
  }
  dependsOn: [
    queryPrivateIPFromSubnet
  ]
}

module appgwDeployment2 '_azure-resoruces/_appgateway.bicep' = if (_selfSignedFrontendCertAndBackendCert) {
  name: '${name_gatewayDeploymentPrefix}2'
  params: {
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    enableCustomSSL: enableCustomSSL
    gatewayPublicIPAddressName: appgwPublicIPAddressName
    gatewaySubnetId: networkDeployment.outputs.subIdForApplicationGateway
    gatewaySslCertName: appgwSslCertName
    gatewayTrustedRootCertName: appgwTrustedRootCertName
    location: location
    noSslCertPsw: true
    sslCertData: existingKeyvault.getSecret(keyvaultFrontendCertDataSecretName)
    sslCertPswData: const_null
    staticPrivateFrontentIP: _appgwUsePrivateIP ? queryPrivateIPFromSubnet.outputs.privateIP : ''
    trustedRootCertData: existingKeyvault.getSecret(keyvaultBackendCertDataSecretName)
    usePrivateIP: appgwUsePrivateIP
  }
  dependsOn: [
    queryPrivateIPFromSubnet
  ]
}

module appgwDeployment3 '_azure-resoruces/_appgateway.bicep' = if (_signedFrontendCertAndNoBackendCert) {
  name: '${name_gatewayDeploymentPrefix}3'
  params: {
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    enableCustomSSL: enableCustomSSL
    gatewayPublicIPAddressName: appgwPublicIPAddressName
    gatewaySubnetId: networkDeployment.outputs.subIdForApplicationGateway
    gatewaySslCertName: appgwSslCertName
    gatewayTrustedRootCertName: appgwTrustedRootCertName
    location: location
    sslCertData: existingKeyvault.getSecret(keyvaultFrontendCertDataSecretName)
    sslCertPswData: existingKeyvault.getSecret(keyvaultFrontendCertPswSecretName)
    staticPrivateFrontentIP: _appgwUsePrivateIP ? queryPrivateIPFromSubnet.outputs.privateIP : ''
    trustedRootCertData: const_null
    usePrivateIP: appgwUsePrivateIP
  }
  dependsOn: [
    queryPrivateIPFromSubnet
  ]
}

module appgwDeployment4 '_azure-resoruces/_appgateway.bicep' = if (_signedFrontendCertAndBackendCert) {
  name: '${name_gatewayDeploymentPrefix}4'
  params: {
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    enableCustomSSL: enableCustomSSL
    gatewayPublicIPAddressName: appgwPublicIPAddressName
    gatewaySubnetId: networkDeployment.outputs.subIdForApplicationGateway
    gatewaySslCertName: appgwSslCertName
    gatewayTrustedRootCertName: appgwTrustedRootCertName
    location: location
    sslCertData: existingKeyvault.getSecret(keyvaultFrontendCertDataSecretName)
    sslCertPswData: existingKeyvault.getSecret(keyvaultFrontendCertPswSecretName)
    staticPrivateFrontentIP: _appgwUsePrivateIP ? queryPrivateIPFromSubnet.outputs.privateIP : ''
    trustedRootCertData: existingKeyvault.getSecret(keyvaultBackendCertDataSecretName)
    usePrivateIP: appgwUsePrivateIP
  }
  dependsOn: [
    queryPrivateIPFromSubnet
  ]
}

module pidAppgwEnd './_pids/_pid.bicep' = {
  name: 'pid-app-gateway-end-deployment'
  params: {
    name: _pidAppgwEnd
  }
  dependsOn: [
    appgwDeployment1
    appgwDeployment2
    appgwDeployment3
    appgwDeployment4
  ]
}

output appGatewayAlias string = ref_gatewayDeployment.outputs.appGatewayAlias
output appGatewayId string = ref_gatewayDeployment.outputs.appGatewayId
output appGatewayName string = ref_gatewayDeployment.outputs.appGatewayName
output appGatewayURL string = uri(ref_gatewayDeployment.outputs.appGatewayURL, '')
output appGatewaySecuredURL string = uri(ref_gatewayDeployment.outputs.appGatewaySecuredURL, '')
// To mitigate ARM-TTK error: Control Named vnetForApplicationGateway must output the resourceGroup property when hideExisting is false
output vnetResourceGroupName string = vnetRGNameForApplicationGateway
// To mitigate ARM-TTK error: Control Named vnetForApplicationGateway must output the newOrExisting property when hideExisting is false
output newOrExisting string = newOrExistingVnetForApplicationGateway
