// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
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
@description('If true, the template will update records to the existing DNS Zone. If false, the template will create a new DNS Zone.')
param createDNSZone bool = false
@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'wlsgw'
@description('Azure DNS Zone name.')
param dnszoneName string = 'contoso.xyz'
param dnszoneAdminConsoleLabel string = 'admin'
@description('Specify a label used to generate subdomain of Application Gateway. The final subdomain name will be label.dnszoneName, e.g. applications.contoso.xyz')
param dnszoneAppGatewayLabel string = 'www'
param dnszoneRGName string = 'dns-contoso-rg'
@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false
param enableDNSConfiguration bool = false
param identity object
@description('Existing Key Vault Name')
param keyVaultName string = 'kv-contoso'
@description('Resource group name in current subscription containing the KeyVault')
param keyVaultResourceGroup string = 'kv-contoso-rg'
@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'
@description('The name of the secret in the specified KeyVault whose value is the password for the SSL Certificate')
param keyVaultSSLCertPasswordSecretName string = 'kv-ssl-psw'
param location string = 'eastus'
@description('Object array to define Load Balancer service, each object must include service name, service target[admin-server or cluster-1], port.')
param lbSvcValues array = []
@secure()
param servicePrincipal string = newGuid()
param utcValue string = utcNow()
@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'

var const_appgwCustomDNSAlias = format('{0}.{1}/', dnszoneAppGatewayLabel, dnszoneName)
var const_appgwAdminCustomDNSAlias = format('{0}.{1}/', dnszoneAdminConsoleLabel, dnszoneName)
var name_dnsNameforApplicationGateway = '${concat(dnsNameforApplicationGateway, take(utcValue, 6))}'
var name_domainLabelforApplicationGateway = '${take(concat(name_dnsNameforApplicationGateway, '-', toLower(resourceGroup().name), '-', toLower(wlsDomainName)), 63)}'

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

module appgwDeployment '_azure-resoruces/_keyvaultAppGatewayConnector.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment'
  params: {
    appGatewayCertificateOption: appGatewayCertificateOption
    customDomainNameforApplicationGateway: format('{0}.{1}', dnszoneAppGatewayLabel, dnszoneName)
    domainLabelforApplicationGateway: name_domainLabelforApplicationGateway
    gatewayPublicIPAddressName: appGatewayPublicIPAddressName
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroup
    keyVaultSSLCertDataSecretName: keyVaultSSLCertDataSecretName
    keyVaultSSLCertPasswordSecretName: keyVaultSSLCertPasswordSecretName
  }
  dependsOn: [
    pidAppgwStart
  ]
}

module dnsZoneDeployment '_azure-resoruces/_dnsZones.bicep' = if (enableDNSConfiguration && createDNSZone) {
  name: 'dnszone-deployment'
  params: {
    dnszoneName: dnszoneName
    location: location
  }
  dependsOn: [
    pidNetworkingStart
  ]
}

module networkingDeployment '_deployment-scripts/_ds-create-networking.bicep' = {
  name: 'ds-networking-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: enableAppGWIngress ? appgwDeployment.outputs.appGatewayName : 'null'
    appgwAlias: enableAppGWIngress ? appgwDeployment.outputs.appGatewayAlias : 'null'
    appgwForAdminServer: appgwForAdminServer
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAppGatewayLabel: dnszoneAppGatewayLabel
    dnszoneName: dnszoneName
    dnszoneRGName: createDNSZone ? resourceGroup().name : dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableDNSConfiguration: enableDNSConfiguration
    identity: identity
    lbSvcValues: lbSvcValues
    location: location
    servicePrincipal: servicePrincipal
    vnetName: enableAppGWIngress ? appgwDeployment.outputs.vnetName : 'null'
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    appgwDeployment
    dnsZoneDeployment
  ]
}

module pidAppgwEnd './_pids/_pid.bicep' = if (enableAppGWIngress) {
  name: 'pid-app-gateway-end-deployment'
  params: {
    name: _pidAppgwEnd
  }
  dependsOn: [
    networkingDeployment
  ]
}

module pidNetworkingEnd './_pids/_pid.bicep' = {
  name: 'pid-networking-end-deployment'
  params: {
    name: _pidNetworkingEnd
  }
  dependsOn: [
    pidAppgwEnd
  ]
}

output adminConsoleExternalUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}console', const_appgwAdminCustomDNSAlias) : format('http://{0}/console', appgwDeployment.outputs.appGatewayAlias)) : networkingDeployment.outputs.adminConsoleLBUrl
output adminConsoleExternalSecuredUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('https://{0}console', const_appgwAdminCustomDNSAlias) : format('https://{0}/console', appgwDeployment.outputs.appGatewayAlias)) : ''
output clusterExternalUrl string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}', const_appgwCustomDNSAlias) : appgwDeployment.outputs.appGatewayURL) : networkingDeployment.outputs.clusterLBUrl
output clusterExternalSecuredURL string = enableAppGWIngress ? (enableDNSConfiguration ? format('https://{0}', const_appgwCustomDNSAlias) : appgwDeployment.outputs.appGatewaySecuredURL) : ''
