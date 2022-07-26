// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''

param appgwAlias string = 'appgw-contoso-alias'
param appgwName string = 'appgw-contoso'
@description('Three scenarios we support for deploying app gateway')
param appgwForAdminServer bool = true
param appgwForRemoteConsole bool = true
param appgwSslCert string = ''
param appgwTrustedRootCert string = ''
param appgwUsePrivateIP bool = false
param aksClusterRGName string = 'aks-contoso-rg'
param aksClusterName string = 'aks-contoso'
param azCliVersion string = ''
param createAKSCluster bool
param dnszoneAdminConsoleLabel string = 'admin'
param dnszoneAdminT3ChannelLabel string = 'admin-t3'
param dnszoneClusterLabel string = 'www'
param dnszoneClusterT3ChannelLabel string = 'cluster-t3'
param dnszoneName string = 'contoso.xyz'
param dnszoneRGName string = 'dns-contoso-rg'
param enableAppGWIngress bool = false
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDNSConfiguration bool = false
param identity object = {}
param lbSvcValues array = []
param location string
param useInternalLB bool = false
param utcValue string = utcNow()
param wlsDomainName string = 'domain1'
param wlsDomainUID string = 'sample-domain1'

var const_commonScript = 'common.sh'
var const_createDnsRecordScript = 'createDnsRecord.sh'
var const_createLbSvcScript = 'createLbSvc.sh'
var const_createGatewayIngressSvcScript = 'createAppGatewayIngress.sh'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_primaryScript = 'setupNetworking.sh'
var const_utilityScript = 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-networking-deployment'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'AKS_CLUSTER_RG_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'APPGW_SSL_CERT_NAME'
        value: appgwSslCert
      }
      {
        name: 'APPGW_TRUSTED_ROOT_CERT_NAME'
        value: appgwTrustedRootCert
      }
      {
        name: 'APPGW_NAME'
        value: appgwName
      }
      {
        name: 'APPGW_USE_PRIVATE_IP'
        value: string(appgwUsePrivateIP)
      }
      {
        name: 'APPGW_FOR_ADMIN_SERVER'
        value: string(appgwForAdminServer)
      }
      {
        name: 'APPGW_FOR_REMOTE_CONSOLE'
        value: string(appgwForRemoteConsole)
      }
      {
        name: 'APPGW_ALIAS'
        value: appgwAlias
      }
      {
        name: 'CREATE_AKS_CLUSTER'
        value: string(createAKSCluster)
      }
      {
        name: 'CURRENT_RG_NAME'
        value: resourceGroup().name
      }
      {
        name: 'DNS_ZONE_NAME'
        value: dnszoneName
      }
      {
        name: 'DNS_ZONE_RG_NAME'
        value: dnszoneRGName
      }
      {
        name: 'DNS_ADMIN_LABEL'
        value: dnszoneAdminConsoleLabel
      }
      {
        name: 'DNS_CLUSTER_LABEL'
        value: dnszoneClusterLabel
      }
      {
        name: 'DNS_ADMIN_T3_LABEL'
        value: dnszoneAdminT3ChannelLabel
      }
      {
        name: 'DNS_CLUSTER_T3_LABEL'
        value: dnszoneClusterT3ChannelLabel
      }
      {
        name: 'ENABLE_DNS_CONFIGURATION'
        value: string(enableDNSConfiguration)
      }
      {
        name: 'ENABLE_AGIC'
        value: string(enableAppGWIngress)
      }
      {
        name: 'ENABLE_CUSTOM_SSL'
        value: string(enableCustomSSL)
      }
      {
        name: 'ENABLE_COOKIE_BASED_AFFINITY'
        value: string(enableCookieBasedAffinity)
      }
      {
        name: 'LB_SVC_VALUES'
        value: string(lbSvcValues)
      }
      {
        name: 'USE_INTERNAL_LB'
        value: string(useInternalLB)
      }
      {
        name: 'WLS_DOMAIN_NAME'
        value: wlsDomainName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_primaryScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
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

output adminConsoleLBEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.adminConsoleEndpoint != 'null') ? format('http://{0}/', deploymentScript.properties.outputs.adminConsoleEndpoint) : ''
output adminConsoleLBSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.adminConsoleEndpoint != 'null') ? format('https://{0}/', deploymentScript.properties.outputs.adminConsoleEndpoint) : ''
output adminServerT3LBEndpoint string = length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.adminServerT3Endpoint != 'null') ? deploymentScript.properties.outputs.adminServerT3Endpoint : ''
output adminRemoteEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.adminRemoteEndpoint != 'null') ? format('http://{0}', deploymentScript.properties.outputs.adminRemoteEndpoint) : ''
output adminRemoteSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.adminRemoteEndpoint != 'null') ? format('https://{0}', deploymentScript.properties.outputs.adminRemoteEndpoint) : ''
output clusterLBEndpoint string = (!enableCustomSSL) && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.clusterEndpoint != 'null') ? format('http://{0}/', deploymentScript.properties.outputs.clusterEndpoint) : ''
output clusterLBSecuredEndpoint string = enableCustomSSL && length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.clusterEndpoint != 'null') ? format('https://{0}/', deploymentScript.properties.outputs.clusterEndpoint) : ''
output clusterT3LBEndpoint string = length(lbSvcValues) > 0 && (deploymentScript.properties.outputs.clusterT3Endpoint != 'null') ? deploymentScript.properties.outputs.clusterT3Endpoint : ''
