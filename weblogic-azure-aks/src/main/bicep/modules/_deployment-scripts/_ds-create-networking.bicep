// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''

param appgwAlias string = 'appgw-contoso-alias'
param appgwName string = 'appgw-contoso'
@allowed([
  'haveCert'
  'haveKeyVault'
  'generateCert'
])
@description('Three scenarios we support for deploying app gateway')
param appgwCertificateOption string = 'haveCert'
param appgwForAdminServer bool = true
param appgwForRemoteConsole bool = true
@secure()
param appgwFrontendSSLCertData string = newGuid()
@secure()
param appgwFrontendSSLCertPsw string = newGuid()
param appgwUsePrivateIP bool = false
param aksClusterRGName string = 'aks-contoso-rg'
param aksClusterName string = 'aks-contoso'
param dnszoneAdminConsoleLabel string = 'admin'
param dnszoneAdminT3ChannelLabel string ='admin-t3'
param dnszoneClusterLabel string = 'www'
param dnszoneClusterT3ChannelLabel string = 'cluster-t3'
param dnszoneName string = 'contoso.xyz'
param dnszoneRGName string = 'dns-contoso-rg'
param enableAppGWIngress bool = false
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDNSConfiguration bool = false
param identity object
param lbSvcValues array = []
param location string
@secure()
param servicePrincipal string = newGuid()
param useInternalLB bool = false
param utcValue string = utcNow()
param wlsDomainName string = 'domain1' 
param wlsDomainUID string = 'sample-domain1'

var const_appgwHelmConfigTemplate='appgw-helm-config.yaml.template'
var const_appgwSARoleBindingFile='appgw-ingress-clusterAdmin-roleBinding.yaml'
var const_arguments = '${aksClusterRGName} ${aksClusterName} ${wlsDomainName} ${wlsDomainUID} "${string(lbSvcValues)}" ${enableAppGWIngress} ${subscription().id} ${resourceGroup().name} ${appgwName} ${appgwUsePrivateIP} ${string(servicePrincipal)} ${appgwForAdminServer} ${enableDNSConfiguration} ${dnszoneRGName} ${dnszoneName} ${dnszoneAdminConsoleLabel} ${dnszoneClusterLabel} ${appgwAlias} ${useInternalLB} ${appgwFrontendSSLCertData} ${appgwFrontendSSLCertPsw} ${appgwCertificateOption} ${enableCustomSSL} ${enableCookieBasedAffinity} ${appgwForRemoteConsole} ${dnszoneAdminT3ChannelLabel} ${dnszoneClusterT3ChannelLabel}'
var const_commonScript = 'common.sh'
var const_createDnsRecordScript = 'createDnsRecord.sh'
var const_createLbSvcScript = 'createLbSvc.sh'
var const_createGatewayIngressSvcScript = 'createAppGatewayIngress.sh'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_setupNetworkingScript= 'setupNetworking.sh'
var const_primaryScript = 'invokeSetupNetworking.sh'
var const_utilityScript= 'utility.sh'
var name_deploymentName='ds-networking-deployment'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-networking-deployment'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.15.0'
    arguments: const_arguments
    primaryScriptUri: uri(const_scriptLocation, '${const_primaryScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_setupNetworkingScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_appgwHelmConfigTemplate}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_appgwSARoleBindingFile}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_createDnsRecordScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_createLbSvcScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_createGatewayIngressSvcScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output adminConsoleLBEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.adminConsoleEndpoint != 'null') ? format('http://{0}/',reference(name_deploymentName).outputs.adminConsoleEndpoint): ''
output adminConsoleLBSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.adminConsoleEndpoint != 'null') ? format('https://{0}/',reference(name_deploymentName).outputs.adminConsoleEndpoint): ''
output adminServerT3LBEndpoint string = length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.adminServerT3Endpoint != 'null') ? reference(name_deploymentName).outputs.adminServerT3Endpoint: ''
output adminRemoteEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.adminRemoteEndpoint != 'null') ? format('http://{0}',reference(name_deploymentName).outputs.adminRemoteEndpoint): ''
output adminRemoteSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.adminRemoteEndpoint != 'null') ? format('https://{0}',reference(name_deploymentName).outputs.adminRemoteEndpoint): ''
output clusterLBEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.clusterEndpoint != 'null') ? format('http://{0}/',reference(name_deploymentName).outputs.clusterEndpoint): ''
output clusterLBSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.clusterEndpoint != 'null') ? format('https://{0}/',reference(name_deploymentName).outputs.clusterEndpoint): ''
output clusterT3LBEndpoint string = length(lbSvcValues) > 0 && (reference(name_deploymentName).outputs.clusterT3Endpoint != 'null') ? reference(name_deploymentName).outputs.clusterT3Endpoint: ''
