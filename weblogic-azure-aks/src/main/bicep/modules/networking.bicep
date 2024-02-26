// Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _pidDnsEnd string = 'pid-networking-dns-end'
param _pidDnsStart string = 'pid-networking-dns-start'
param _pidLbEnd string = 'pid-networking-lb-end'
param _pidLbStart string = 'pid-networking-lb-start'
param _pidNetworkingEnd string = 'pid-networking-end'
param _pidNetworkingStart string = 'pid-networking-start'
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = 'aks-contoso-rg'
@description('Name of an existing AKS cluster.')
param aksClusterName string = 'aks-contoso'
param appGatewayName string = ''
param appGatewayAlias string = ''
param appGatewaySecuredURL string = ''
param appGatewaySslCert string = ''
param appGatewayTrustedRootCert string = ''
param appGatewayURL string = ''
@description('Create Application Gateway ingress for admin console.')
param appgwForAdminServer bool = true
@description('Create Application Gateway ingress for remote console.')
param appgwForRemoteConsole bool = true
param appgwUsePrivateIP bool = false
param azCliVersion string = ''
param createAKSCluster bool = true
@description('If true, the template will update records to the existing DNS Zone. If false, the template will create a new DNS Zone.')
param createDNSZone bool = false
@description('Azure DNS Zone name.')
param dnszoneName string = 'contoso.xyz'
param dnszoneAdminConsoleLabel string = 'admin'
param dnszoneAdminT3ChannelLabel string = 'admin-t3'
@description('Specify a label used to generate subdomain of WebLogic cluster. The final subdomain name will be label.dnszoneName, e.g. applications.contoso.xyz')
param dnszoneClusterLabel string = 'www'
param dnszoneClusterT3ChannelLabel string = 'cluster-t3'
param dnszoneRGName string = 'dns-contoso-rg'
@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDNSConfiguration bool = false
param identity object = {}
param location string
@description('Object array to define Load Balancer service, each object must include service name, service target[admin-server or cluster-1], port.')
param lbSvcValues array = []
@description('True to set up internal load balancer service.')
param useInternalLB bool = false
@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'

// To mitigate arm-ttk error: Type Mismatch: Parameter in nested template is defined as string, but the parent template defines it as bool.
var _enableAppGWIngress = enableAppGWIngress
var const_appgwCustomDNSAlias = format('{0}.{1}/', dnszoneClusterLabel, dnszoneName)
var const_appgwAdminCustomDNSAlias = format('{0}.{1}/', dnszoneAdminConsoleLabel, dnszoneName)
var const_enableLbService = length(lbSvcValues) > 0
var ref_networkDeployment = _enableAppGWIngress ? networkingDeploymentYesAppGW : networkingDeploymentNoAppGW

module pidNetworkingStart './_pids/_pid.bicep' = {
  name: 'pid-networking-start-deployment'
  params: {
    name: _pidNetworkingStart
  }
}

module pidLbStart './_pids/_pid.bicep' = if (const_enableLbService) {
  name: 'pid-loadbalancer-service-start-deployment'
  params: {
    name: _pidLbStart
  }
}

module pidDnsStart './_pids/_pid.bicep' = if (enableDNSConfiguration) {
  name: 'pid-dns-start-deployment'
  params: {
    name: _pidDnsStart
  }
}

module dnsZoneDeployment '_azure-resoruces/_dnsZones.bicep' = if (enableDNSConfiguration && createDNSZone) {
  name: 'dnszone-deployment'
  params: {
    dnszoneName: dnszoneName
  }
  dependsOn: [
    pidNetworkingStart
    pidDnsStart
  ]
}

module installAgic '_deployment-scripts/_ds_install_agic.bicep' = if (enableAppGWIngress) {
  name: 'install-agic'
  params: {
    location: location
    identity: identity
    aksClusterRGName: aksClusterRGName
    appgwName: appGatewayName
    aksClusterName: aksClusterName
    azCliVersion: azCliVersion
  }
  dependsOn: [
    pidNetworkingStart
  ]
}

module agicRoleAssignment '_rolesAssignment/_agicRoleAssignment.bicep' = if (enableAppGWIngress) {
  name: 'allow-agic-access-current-resource-group'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
  }
  dependsOn: [
    installAgic
  ]
}

module validateAgic '_deployment-scripts/_ds_validate_agic.bicep' = if (enableAppGWIngress) {
  name: 'validate-agic'
  params: {
    location: location
    identity: identity
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    azCliVersion: azCliVersion
  }
  dependsOn: [
    agicRoleAssignment
  ]
}

module networkingDeploymentYesAppGW '_deployment-scripts/_ds-create-networking.bicep' = if (enableAppGWIngress) {
  name: 'ds-networking-deployment-yes-appgw'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: appGatewayName
    appgwAlias: appGatewayAlias
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    appgwSslCert: appGatewaySslCert
    appgwTrustedRootCert: appGatewayTrustedRootCert
    appgwUsePrivateIP: appgwUsePrivateIP
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    azCliVersion: azCliVersion
    createAKSCluster: createAKSCluster
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
    useInternalLB: useInternalLB
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    dnsZoneDeployment
    validateAgic
  ]
}

module networkingDeploymentNoAppGW '_deployment-scripts/_ds-create-networking.bicep' = if (!enableAppGWIngress) {
  name: 'ds-networking-deployment-no-appgw'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appgwName: 'null'
    appgwAlias: 'null'
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    appgwSslCert: appGatewaySslCert
    appgwTrustedRootCert: appGatewayTrustedRootCert
    appgwUsePrivateIP: appgwUsePrivateIP
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    azCliVersion: azCliVersion
    createAKSCluster: createAKSCluster
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
    useInternalLB: useInternalLB
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    dnsZoneDeployment
    validateAgic
  ]
}

module pidLbEnd './_pids/_pid.bicep' = if (const_enableLbService) {
  name: 'pid-loadbalancer-service-end-deployment'
  params: {
    name: _pidLbEnd
  }
  dependsOn: [
    networkingDeploymentYesAppGW
    networkingDeploymentNoAppGW
  ]
}

module pidDnsEnd './_pids/_pid.bicep' = if (enableDNSConfiguration) {
  name: 'pid-dns-end-deployment'
  params: {
    name: _pidDnsEnd
  }
  dependsOn: [
    networkingDeploymentYesAppGW
    networkingDeploymentNoAppGW
  ]
}

module pidNetworkingEnd './_pids/_pid.bicep' = {
  name: 'pid-networking-end-deployment'
  params: {
    name: _pidNetworkingEnd
  }
  dependsOn: [
    pidLbEnd
    pidDnsEnd
  ]
}

output adminConsoleExternalEndpoint string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}console', const_appgwAdminCustomDNSAlias) : format('http://{0}/console', appGatewayAlias)) : ref_networkDeployment.outputs.adminConsoleLBEndpoint
output adminConsoleExternalSecuredEndpoint string = enableAppGWIngress && enableCustomSSL && enableDNSConfiguration ? format('https://{0}console', const_appgwAdminCustomDNSAlias) : ref_networkDeployment.outputs.adminConsoleLBSecuredEndpoint
output adminRemoteConsoleEndpoint string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}remoteconsole', const_appgwAdminCustomDNSAlias) : format('http://{0}/remoteconsole', appGatewayAlias)) : ref_networkDeployment.outputs.adminRemoteEndpoint
output adminRemoteConsoleSecuredEndpoint string = enableAppGWIngress && enableCustomSSL && enableDNSConfiguration ? format('https://{0}remoteconsole', const_appgwAdminCustomDNSAlias) : ref_networkDeployment.outputs.adminRemoteSecuredEndpoint
output adminServerT3ChannelEndpoint string = format('{0}://{1}', enableCustomSSL ? 't3s' : 't3', ref_networkDeployment.outputs.adminServerT3LBEndpoint)
output clusterExternalEndpoint string = enableAppGWIngress ? (enableDNSConfiguration ? format('http://{0}', const_appgwCustomDNSAlias) : appGatewayURL) : ref_networkDeployment.outputs.clusterLBEndpoint
output clusterExternalSecuredEndpoint string = enableAppGWIngress ? (enableDNSConfiguration ? format('https://{0}', const_appgwCustomDNSAlias) : appGatewaySecuredURL) : ref_networkDeployment.outputs.clusterLBSecuredEndpoint
output clusterT3ChannelEndpoint string = format('{0}://{1}', enableCustomSSL ? 't3s' : 't3', ref_networkDeployment.outputs.clusterT3LBEndpoint)
