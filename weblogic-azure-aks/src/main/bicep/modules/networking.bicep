// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _pidNetworkingEnd string
param _pidNetworkingStart string
param _pidAppgwEnd string
param _pidAppgwStart string
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = 'aks-contoso-rg'
@description('Name of an existing AKS cluster.')
param aksClusterName string = 'aks-contoso'
@allowed([
  'haveCert'
  'haveKeyVault'
  'generateCert'
])
@description('Three scenarios we support for deploying app gateway')
param appGatewayCertificateOption string = 'haveCert'
@description('Public IP Name for the Application Gateway')
param appGatewayPublicIPAddressName string = 'gwip'
@description('Create Application Gateway ingress for admin console.')
param appgwForAdminServer bool = true
@description('Create Application Gateway ingress for remote console.')
param appgwForRemoteConsole bool = true
@description('If true, the template will update records to the existing DNS Zone. If false, the template will create a new DNS Zone.')
param createDNSZone bool = false
@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'wlsgw'
@description('Azure DNS Zone name.')
param dnszoneName string = 'contoso.xyz'
param dnszoneAdminConsoleLabel string = 'admin'
param dnszoneAdminT3ChannelLabel string ='admin-t3'
@description('Specify a label used to generate subdomain of WebLogic cluster. The final subdomain name will be label.dnszoneName, e.g. applications.contoso.xyz')
param dnszoneClusterLabel string = 'www'
param dnszoneClusterT3ChannelLabel string = 'cluster-t3'
param dnszoneRGName string = 'dns-contoso-rg'
@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDNSConfiguration bool = false
param identity object
@description('Existing Key Vault Name')
param keyVaultName string = 'kv-contoso'
@description('Resource group name in current subscription containing the KeyVault')
param keyVaultResourceGroup string = 'kv-contoso-rg'
param keyvaultBackendCertDataSecretName string = 'kv-ssl-backend-data'
@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'
@description('The name of the secret in the specified KeyVault whose value is the password for the SSL Certificate')
param keyVaultSSLCertPasswordSecretName string = 'kv-ssl-psw'
param location string
@description('Object array to define Load Balancer service, each object must include service name, service target[admin-server or cluster-1], port.')
param lbSvcValues array = []
@secure()
param servicePrincipal string = newGuid()
@description('True to set up internal load balancer service.')
param useInternalLB bool = false
@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'

var const_appgwCustomDNSAlias = format('{0}.{1}/', dnszoneClusterLabel, dnszoneName)
var const_appgwAdminCustomDNSAlias = format('{0}.{1}/', dnszoneAdminConsoleLabel, dnszoneName)
var const_appgwSSLCertOptionGenerateCert = 'generateCert'
var name_networkDeployment = enableAppGWIngress ? (appGatewayCertificateOption == const_appgwSSLCertOptionGenerateCert ? 'ds-networking-deployment-1': 'ds-networking-deployment') : 'ds-networking-deployment-2'
var ref_networkDeployment = reference(name_networkDeployment)

module pidNetworkingStart './_pids/_pid.bicep' = {
  name: 'pid-networking-start-deployment'
  params: {
    name: _pidNetworkingStart
  }
}

module pidAppgwStart './_pids/_pid.bicep' = if (enableAppGWIngress) {
  name: 'pid-app-gateway-start-deployment'
  params: {
    name: _pidAppgwStart
  }
}

// get key vault object in a resource group
resource existingKeyvault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if (enableAppGWIngress) {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

module appgwDeployment '_azure-resoruces/_appgateway.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment'
  params: {
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    gatewayPublicIPAddressName: appGatewayPublicIPAddressName
    location: location
  }
  dependsOn: [
    pidAppgwStart
  ]
}

/*
  Upload trusted root certificate to Azure Application Gateway
  To set up e2e TLS/SSL communication between Azure Application Gateway and WebLogic admin server or WebLogic cluster.
  The certificate must be the CA certificate of WebLogic Server identity.
*/
module appgwBackendCertDeployment '_deployment-scripts/_ds-appgw-upload-trusted-root-certificate.bicep' = if (enableAppGWIngress && enableCustomSSL) {
  name: 'app-gateway-backend-cert-deployment'
  params: {
    appgwName: enableAppGWIngress ? appgwDeployment.outputs.appGatewayName : 'null'
    sslBackendRootCertData: existingKeyvault.getSecret(keyvaultBackendCertDataSecretName)
    identity: identity
    location: location
  }
  dependsOn: [
    appgwDeployment
  ]
}



module dnsZoneDeployment '_azure-resoruces/_dnsZones.bicep' = if (enableDNSConfiguration && createDNSZone) {
  name: 'dnszone-deployment'
  params: {
    dnszoneName: dnszoneName
  }
  dependsOn: [
    pidNetworkingStart
  ]
}

module networkingDeployment '_deployment-scripts/_ds-create-networking.bicep' = if (enableAppGWIngress && appGatewayCertificateOption != const_appgwSSLCertOptionGenerateCert) {
  name: 'ds-networking-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: enableAppGWIngress ? appgwDeployment.outputs.appGatewayName : 'null'
    appgwAlias: enableAppGWIngress ? appgwDeployment.outputs.appGatewayAlias : 'null'
    appgwCertificateOption: appGatewayCertificateOption
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    appgwFrontendSSLCertData: existingKeyvault.getSecret(keyVaultSSLCertDataSecretName)
    appgwFrontendSSLCertPsw: existingKeyvault.getSecret(keyVaultSSLCertPasswordSecretName)
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAdminT3ChannelLabel: dnszoneAdminT3ChannelLabel
    dnszoneClusterLabel: dnszoneClusterLabel
    dnszoneClusterT3ChannelLabel: dnszoneClusterT3ChannelLabel
    dnszoneName: dnszoneName
    dnszoneRGName: createDNSZone ? resourceGroup().name : dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCookieBasedAffinity: enableCookieBasedAffinity
    enableCustomSSL: enableCustomSSL
    enableDNSConfiguration: enableDNSConfiguration
    identity: identity
    lbSvcValues: lbSvcValues
    location: location
    servicePrincipal: servicePrincipal
    useInternalLB: useInternalLB
    vnetName: enableAppGWIngress ? appgwDeployment.outputs.vnetName : 'null'
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    appgwBackendCertDeployment
    dnsZoneDeployment
  ]
}

// Wrokaround for "Error BCP180: Function "getSecret" is not valid at this location. It can only be used when directly assigning to a module parameter with a secure decorator."
module networkingDeployment2 '_deployment-scripts/_ds-create-networking.bicep' = if (enableAppGWIngress && appGatewayCertificateOption == const_appgwSSLCertOptionGenerateCert) {
  name: 'ds-networking-deployment-1'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: enableAppGWIngress ? appgwDeployment.outputs.appGatewayName : 'null'
    appgwAlias: enableAppGWIngress ? appgwDeployment.outputs.appGatewayAlias : 'null'
    appgwCertificateOption: appGatewayCertificateOption
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    appgwFrontendSSLCertData: existingKeyvault.getSecret(keyVaultSSLCertDataSecretName)
    appgwFrontendSSLCertPsw: 'null'
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAdminT3ChannelLabel: dnszoneAdminT3ChannelLabel
    dnszoneClusterLabel: dnszoneClusterLabel
    dnszoneClusterT3ChannelLabel: dnszoneClusterT3ChannelLabel
    dnszoneName: dnszoneName
    dnszoneRGName: createDNSZone ? resourceGroup().name : dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCustomSSL: enableCustomSSL
    enableCookieBasedAffinity: enableCookieBasedAffinity
    enableDNSConfiguration: enableDNSConfiguration
    identity: identity
    lbSvcValues: lbSvcValues
    location: location
    servicePrincipal: servicePrincipal
    useInternalLB: useInternalLB
    vnetName: enableAppGWIngress ? appgwDeployment.outputs.vnetName : 'null'
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    appgwBackendCertDeployment
    dnsZoneDeployment
  ]
}

module networkingDeployment3 '_deployment-scripts/_ds-create-networking.bicep' = if (!enableAppGWIngress) {
  name: 'ds-networking-deployment-2'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: 'null'
    appgwAlias: 'null'
    appgwCertificateOption: appGatewayCertificateOption
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    appgwFrontendSSLCertData: 'null'
    appgwFrontendSSLCertPsw: 'null'
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAdminT3ChannelLabel: dnszoneAdminT3ChannelLabel
    dnszoneClusterLabel: dnszoneClusterLabel
    dnszoneClusterT3ChannelLabel: dnszoneClusterT3ChannelLabel
    dnszoneName: dnszoneName
    dnszoneRGName: createDNSZone ? resourceGroup().name : dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCookieBasedAffinity: enableCookieBasedAffinity
    enableCustomSSL: enableCustomSSL
    enableDNSConfiguration: enableDNSConfiguration
    identity: identity
    lbSvcValues: lbSvcValues
    location: location
    servicePrincipal: servicePrincipal
    useInternalLB: useInternalLB
    vnetName: 'null'
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    dnsZoneDeployment
  ]
}

module pidAppgwEnd './_pids/_pid.bicep' = if (enableAppGWIngress) {
  name: 'pid-app-gateway-end-deployment'
  params: {
    name: _pidAppgwEnd
  }
  dependsOn: [
    appgwDeployment
  ]
}

module pidNetworkingEnd './_pids/_pid.bicep' = {
  name: 'pid-networking-end-deployment'
  params: {
    name: _pidNetworkingEnd
  }
  dependsOn: [
    networkingDeployment
    networkingDeployment2
    networkingDeployment3
  ]
}

output adminConsoleExternalUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}console', const_appgwAdminCustomDNSAlias) : format('http://{0}/console', appgwDeployment.outputs.appGatewayAlias)) : ref_networkDeployment.outputs.adminConsoleLBUrl.value
output adminConsoleExternalSecuredUrl string = enableAppGWIngress && enableCustomSSL && enableDNSConfiguration ? format('https://{0}console', const_appgwAdminCustomDNSAlias) : ref_networkDeployment.outputs.adminConsoleLBSecuredUrl.value
output adminRemoteConsoleUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}remoteconsole', const_appgwAdminCustomDNSAlias) : format('http://{0}/remoteconsole', appgwDeployment.outputs.appGatewayAlias)) : ref_networkDeployment.outputs.adminRemoteUrl.value
output adminRemoteConsoleSecuredUrl string = enableAppGWIngress && enableCustomSSL && enableDNSConfiguration ? format('https://{0}remoteconsole', const_appgwAdminCustomDNSAlias) : ref_networkDeployment.outputs.adminRemoteSecuredUrl.value
output adminServerT3ChannelUrl string = ref_networkDeployment.outputs.adminServerT3LBUrl.value
output clusterExternalUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}', const_appgwCustomDNSAlias) : appgwDeployment.outputs.appGatewayURL) : ref_networkDeployment.outputs.clusterLBUrl.value
output clusterExternalSecuredUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('https://{0}', const_appgwCustomDNSAlias) : appgwDeployment.outputs.appGatewaySecuredURL) : ref_networkDeployment.outputs.clusterLBSecuredUrl.value
output clusterT3ChannelUrl string = ref_networkDeployment.outputs.clusterT3LBUrl.value
