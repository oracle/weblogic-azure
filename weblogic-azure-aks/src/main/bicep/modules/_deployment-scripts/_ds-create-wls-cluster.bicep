// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''

param aksClusterRGName string = ''
param aksClusterName string = ''
param acrName string = ''
param acrResourceGroupName string = ''
param appPackageUrls array = []
param appReplicas int = 2
param azCliVersion string = ''
param cpuPlatform string = ''
param databaseType string = 'oracle'
param dbDriverLibrariesUrls array = []
param enableCustomSSL bool = false
param enableAdminT3Tunneling bool = false
param enableClusterT3Tunneling bool = false
param enablePswlessConnection bool = false
param enablePV bool = false
param fileShareName string
param identity object = {}
param isSSOSupportEntitled bool
param location string
param managedServerPrefix string = 'managed-server'
@secure()
param ocrSSOPSW string
param ocrSSOUser string
param storageAccountName string = 'null'
@description('${label.tagsLabel}')
param tagsByResource object
param t3ChannelAdminPort int = 7005
param t3ChannelClusterPort int = 8011
param utcValue string = utcNow()
param userProvidedImagePath string = 'null'
param useOracleImage bool = true
@secure()
param wdtRuntimePassword string
param wlsClusterSize int = 5
param wlsCPU string = '200m'
param wlsDomainName string = 'domain1'
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsIdentityKeyStoreData string =newGuid()
@secure()
param wlsIdentityKeyStorePassphrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsIdentityKeyStoreType string = 'PKCS12'
param wlsImageTag string = '12.2.1.4'
param wlsJavaOption string = 'null'
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
@secure()
param wlsPrivateKeyAlias string =newGuid()
@secure()
param wlsPrivateKeyPassPhrase string = newGuid()
@secure()
param wlsTrustKeyStoreData string = newGuid()
@secure()
param wlsTrustKeyStorePassPhrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsTrustKeyStoreType string = 'PKCS12'
param wlsUserName string = 'weblogic'

var const_buildDockerImageScript='createVMAndBuildImage.sh'
var const_commonScript = 'common.sh'
var const_pvTempalte = 'pv.yaml.template'
var const_pvcTempalte = 'pvc.yaml.template'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_genDomainConfigScript= 'genDomainConfig.sh'
var const_setUpDomainScript = 'setupWLSDomain.sh'
var const_updateDomainConfigScript= 'updateDomainConfig.sh'
var const_utilityScript= 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-wls-cluster-creation'
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['${identifier.deploymentScripts}']
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
      }
      {
        name: 'ACR_RESOURCEGROUP_NAME'
        value: acrResourceGroupName
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
        name: 'CPU_PLATFORM'
        value: cpuPlatform
      }
      {
        name: 'CURRENT_RESOURCEGROUP_NAME'
        value: resourceGroup().name
      }
      {
        name: 'DB_TYPE'
        value: databaseType
      }
      {
        name: 'ENABLE_ADMIN_CUSTOM_T3'
        value: string(enableAdminT3Tunneling)
      }
      {
        name: 'ENABLE_CLUSTER_CUSTOM_T3'
        value: string(enableClusterT3Tunneling)
      }
      {
        name: 'ENABLE_CUSTOM_SSL'
        value: string(enableCustomSSL)
      }
      {
        name: 'ENABLE_PASSWORDLESS_DB_CONNECTION'
        value: string(enablePswlessConnection)
      }
      {
        name: 'ENABLE_PV'
        value: string(enablePV)
      }
      {
        name: 'FILE_SHARE_NAME'
        value: fileShareName
      }
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
        name: 'SCRIPT_LOCATION'
        value: const_scriptLocation
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: storageAccountName
      }
      {
        name: 'URL_3RD_DATASOURCE'
        value:  string(dbDriverLibrariesUrls)
      }
      {
        name: 'USE_ORACLE_IMAGE'
        value: string(useOracleImage)
      }
      {
        name: 'USER_PROVIDED_IMAGE_PATH'
        value: userProvidedImagePath
      }
      {
        name: 'WLS_ADMIN_PASSWORD'
        secureValue: wlsPassword
      }
      {
        name: 'WLS_ADMIN_USER_NAME'
        secureValue: wlsUserName
      }
      {
        name: 'WLS_APP_PACKAGE_URLS'
        value: base64(string(appPackageUrls))
      }
      {
        name: 'WLS_APP_REPLICAS'
        value: string(appReplicas)
      }
      {
        name: 'WLS_CLUSTER_SIZE'
        value: string(wlsClusterSize)
      }
      {
        name: 'WLS_DOMAIN_NAME'
        value: wlsDomainName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
      {
        name: 'WLS_IMAGE_TAG'
        value: wlsImageTag
      }
      {
        name: 'WLS_JAVA_OPTIONS'
        value: wlsJavaOption
      }
      {
        name: 'WLS_MANAGED_SERVER_PREFIX'
        value: managedServerPrefix
      }
      {
        name: 'WLS_RESOURCE_REQUEST_CPU'
        value: wlsCPU
      }
      {
        name: 'WLS_RESOURCE_REQUEST_MEMORY'
        value: wlsMemory
      }
      {
        name: 'WLS_SSL_IDENTITY_DATA'
        secureValue: wlsIdentityKeyStoreData
      }
      {
        name: 'WLS_SSL_IDENTITY_PASSWORD'
        secureValue: wlsIdentityKeyStorePassphrase
      }
      {
        name: 'WLS_SSL_IDENTITY_TYPE'
        value: wlsIdentityKeyStoreType
      }
      {
        name: 'WLS_SSL_TRUST_DATA'
        secureValue: wlsTrustKeyStoreData
      }
      {
        name: 'WLS_SSL_TRUST_PASSWORD'
        secureValue: wlsTrustKeyStorePassPhrase
      }
      {
        name: 'WLS_SSL_TRUST_TYPE'
        value: wlsTrustKeyStoreType
      }
      {
        name: 'WLS_SSL_PRIVATE_KEY_ALIAS'
        secureValue: wlsPrivateKeyAlias
      }
      {
        name: 'WLS_SSL_PRIVATE_KEY_PASSWORD'
        secureValue: wlsPrivateKeyPassPhrase
      }
      {
        name: 'WLS_T3_ADMIN_PORT'
        value: string(t3ChannelAdminPort)
      }
      {
        name: 'WLS_T3_CLUSTER_PORT'
        value: string(t3ChannelClusterPort)
      }
      {
        name: 'WLS_WDT_RUNTIME_PSW'
        secureValue: wdtRuntimePassword
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_setUpDomainScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_genDomainConfigScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pvTempalte}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pvcTempalte}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_buildDockerImageScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_updateDomainConfigScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
