// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param acrName string
param aksAgentPoolNodeCount int
param aksAgentPoolVMSize string
param aksClusterRGName string
param aksClusterName string
param aksVersion string
param appGatewayCertificateOption string
param appGatewaySSLCertData string
@secure()
param appGatewaySSLCertPassword string
param createAKSCluster bool
param createDNSZone bool
param dnszoneName string
param dnszoneRGName string
param enableAppGWIngress bool
param enableCustomSSL bool
param enableDNSConfiguration bool
param keyVaultName string
param keyVaultResourceGroup string
param keyVaultSSLCertDataSecretName string
param keyVaultSSLCertPasswordSecretName string
param identity object
param isSSOSupportEntitled bool
param location string
@secure()
param ocrSSOPSW string
param ocrSSOUser string
@secure()
param servicePrincipal string
param sslConfigurationAccessOption string
param sslKeyVaultCustomIdentityKeyStoreDataSecretName string
param sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName string
param sslKeyVaultCustomIdentityKeyStoreType string
param sslKeyVaultCustomTrustKeyStoreDataSecretName string
param sslKeyVaultCustomTrustKeyStorePassPhraseSecretName string
param sslKeyVaultCustomTrustKeyStoreType string
param sslKeyVaultName string
param sslKeyVaultPrivateKeyAliasSecretName string
param sslKeyVaultPrivateKeyPassPhraseSecretName string
param sslKeyVaultResourceGroup string
param sslUploadedCustomIdentityKeyStoreData string
@secure()
param sslUploadedCustomIdentityKeyStorePassphrase string
param sslUploadedCustomIdentityKeyStoreType string
param sslUploadedCustomTrustKeyStoreData string
@secure()
param sslUploadedCustomTrustKeyStorePassPhrase string
param sslUploadedCustomTrustKeyStoreType string
param sslUploadedPrivateKeyAlias string
@secure()
param sslUploadedPrivateKeyPassPhrase string
param useAksWellTestedVersion bool
param userProvidedAcr string
param userProvidedImagePath string
param useOracleImage bool
param utcValue string = utcNow()
param wlsImageTag string

var const_arguments = '${location} ${createAKSCluster} ${aksAgentPoolVMSize} ${aksAgentPoolNodeCount} ${useOracleImage} ${wlsImageTag} ${userProvidedImagePath} ${enableCustomSSL} ${sslConfigurationAccessOption} ${appGatewayCertificateOption} ${enableAppGWIngress} ${const_checkDNSZone}'
var const_azcliVersion = '2.15.0'
var const_checkDNSZone = enableDNSConfiguration && !createDNSZone
var const_deploymentName = 'ds-validate-parameters-and-fail-fast'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
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
        name: 'ACR_NAME_FOR_USER_PROVIDED_IMAGE'
        value: userProvidedAcr
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
        name: 'BASE64_FOR_SERVICE_PRINCIPAL'
        secureValue: servicePrincipal
      }
      {
        name: 'WLS_SSL_KEYVAULT_NAME'
        value: sslKeyVaultName
      }
      {
        name: 'WLS_SSL_KEYVAULT_RESOURCEGROUP_NAME'
        value: sslKeyVaultResourceGroup
      }
      {
        name: 'WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME'
        value: sslKeyVaultCustomIdentityKeyStoreDataSecretName
      }
      {
        name: 'WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME'
        value: sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName
      }
      {
        name: 'WLS_SSL_KEYVAULT_IDENTITY_TYPE'
        value: sslKeyVaultCustomIdentityKeyStoreType
      }
      {
        name: 'WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME'
        value: sslKeyVaultCustomTrustKeyStoreDataSecretName
      }
      {
        name: 'WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME'
        value: sslKeyVaultCustomTrustKeyStorePassPhraseSecretName
      }
      {
        name: 'WLS_SSL_KEYVAULT_TRUST_TYPE'
        value: sslKeyVaultCustomTrustKeyStoreType
      }
      {
        name: 'WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS'
        value: sslKeyVaultPrivateKeyAliasSecretName
      }
      {
        name: 'WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD'
        value: sslKeyVaultPrivateKeyPassPhraseSecretName
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
        name: 'APPLICATION_GATEWAY_SSL_KEYVAULT_NAME'
        value: keyVaultName
      }
      {
        name: 'APPLICATION_GATEWAY_SSL_KEYVAULT_RESOURCEGROUP'
        value: keyVaultResourceGroup
      }
      {
        name: 'APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME'
        value: keyVaultSSLCertDataSecretName
      }
      {
        name: 'APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME'
        value: keyVaultSSLCertPasswordSecretName
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
        name: 'DNA_ZONE_NAME'
        value: dnszoneName
      }
      {
        name: 'DNA_ZONE_RESOURCEGROUP_NAME'
        value: dnszoneRGName
      }
      {
        name: 'USE_AKS_WELL_TESTED_VERSION'
        value: string(useAksWellTestedVersion)
      }
    ]
    scriptContent: format('{0}\r\n\r\n{1}', loadTextContent('../../../arm/scripts/common.sh'), loadTextContent('../../../arm/scripts/inline-scripts/validateParameters.sh'))
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}


output aksVersion string = reference(const_deploymentName).outputs.aksVersion
