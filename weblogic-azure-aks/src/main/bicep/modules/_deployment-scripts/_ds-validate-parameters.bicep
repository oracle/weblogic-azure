// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _globalResourceNameSufix string
param acrName string
param acrResourceGroupName string
param aksAgentPoolNodeCount int
param aksAgentPoolVMSize string = ''
param aksClusterRGName string
param aksClusterName string
param aksVersion string = 'default'
param appGatewayCertificateOption string
param appGatewaySSLCertData string
@secure()
param appGatewaySSLCertPassword string
param appReplicas int
param azCliVersion string = ''
param createAKSCluster bool
param createDNSZone bool
param dnszoneName string
param dnszoneRGName string
param enableAppGWIngress bool
param enableCustomSSL bool
param enableDNSConfiguration bool
param identity object = {}
param isSSOSupportEntitled bool
param location string
@secure()
param ocrSSOPSW string
param ocrSSOUser string
@secure()
param sslUploadedCustomIdentityKeyStoreData string
@secure()
param sslUploadedCustomIdentityKeyStorePassphrase string
param sslUploadedCustomIdentityKeyStoreType string
@secure()
param sslUploadedCustomTrustKeyStoreData string
@secure()
param sslUploadedCustomTrustKeyStorePassPhrase string
param sslUploadedCustomTrustKeyStoreType string
@secure()
param sslUploadedPrivateKeyAlias string
@secure()
param sslUploadedPrivateKeyPassPhrase string
@description('${label.tagsLabel}')
param tagsByResource object
param useAksWellTestedVersion bool = true
param userProvidedAcr string
param userProvidedAcrRgName string
param userProvidedImagePath string
param useOracleImage bool
param vnetForApplicationGateway object
param utcValue string = utcNow()
param wlsImageTag string

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_common = loadFileAsBase64('../../../arm/scripts/common.sh')
var base64_utility = loadFileAsBase64('../../../arm/scripts/utility.sh')
var base64_validateParameters = loadFileAsBase64('../../../arm/scripts/inline-scripts/validateParameters.sh')
var const_arguments = '${location} ${createAKSCluster} ${aksAgentPoolVMSize} ${aksAgentPoolNodeCount} ${useOracleImage} ${wlsImageTag} ${userProvidedImagePath} ${enableCustomSSL} ${appGatewayCertificateOption} ${enableAppGWIngress} ${const_checkDNSZone}'
var const_checkDNSZone = enableDNSConfiguration && !createDNSZone
var const_deploymentName = 'ds-validate-parameters-and-fail-fast-${_globalResourceNameSufix}'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['${identifier.deploymentScripts}']
  properties: {
    azCliVersion: azCliVersion
    arguments: const_arguments
    environmentVariables: [
      {
        name: 'ORACLE_ACCOUNT_NAME'
        value: ocrSSOUser
      }
      {
        name: 'ORACLE_ACCOUNT_PASSWORD'
        secureValue: ocrSSOPSW
      }
      {
        name: 'ORACLE_ACCOUNT_ENTITLED'
        value: string(isSSOSupportEntitled)
      }
      {
        name: 'ACR_NAME'
        value: acrName
      }
      {
        name: 'ACR_RESOURCE_GROUP'
        value: acrResourceGroupName
      }
      {
        name: 'ACR_NAME_FOR_USER_PROVIDED_IMAGE'
        value: userProvidedAcr
      }
      {
        name: 'ACR_RG_NAME_FOR_USER_PROVIDED_IMAGE'
        value: userProvidedAcrRgName
      }
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'AKS_CLUSTER_RESOURCEGROUP_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_VERSION'
        value: aksVersion
      }
      {
        name: 'APP_REPLICAS'
        value: appReplicas
      }
      {
        name: 'WLS_SSL_IDENTITY_DATA'
        secureValue: sslUploadedCustomIdentityKeyStoreData
      }
      {
        name: 'WLS_SSL_IDENTITY_PASSWORD'
        secureValue: sslUploadedCustomIdentityKeyStorePassphrase
      }
      {
        name: 'WLS_SSL_IDENTITY_TYPE'
        value: sslUploadedCustomIdentityKeyStoreType
      }
      {
        name: 'WLS_SSL_TRUST_DATA'
        secureValue: sslUploadedCustomTrustKeyStoreData
      }
      {
        name: 'WLS_SSL_TRUST_PASSWORD'
        secureValue: sslUploadedCustomTrustKeyStorePassPhrase
      }
      {
        name: 'WLS_SSL_TRUST_TYPE'
        value: sslUploadedCustomTrustKeyStoreType
      }
      {
        name: 'WLS_SSL_PRIVATE_KEY_ALIAS'
        secureValue: sslUploadedPrivateKeyAlias
      }
      {
        name: 'WLS_SSL_PRIVATE_KEY_PASSWORD'
        secureValue: sslUploadedPrivateKeyPassPhrase
      }
      {
        name: 'APPLICATION_GATEWAY_SSL_FRONTEND_CERT_DATA'
        value: appGatewaySSLCertData
      }
      {
        name: 'APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD'
        value: appGatewaySSLCertPassword
      }
      {
        name: 'DNS_ZONE_NAME'
        value: dnszoneName
      }
      {
        name: 'DNS_ZONE_RESOURCEGROUP_NAME'
        value: dnszoneRGName
      }
      {
        name: 'USE_AKS_WELL_TESTED_VERSION'
        value: string(useAksWellTestedVersion)
      }
      {
        name: 'VNET_FOR_APPLICATIONGATEWAY'
        value: string(vnetForApplicationGateway)
      }
    ]
    scriptContent: format('{0}\r\n\r\n{1}\r\n\r\n{2}', base64ToString(base64_common), base64ToString(base64_utility), base64ToString(base64_validateParameters))
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output aksVersion string = deploymentScript.properties.outputs.aksVersion
output aksAgentAvailabilityZones array = json(deploymentScript.properties.outputs.agentAvailabilityZones)
