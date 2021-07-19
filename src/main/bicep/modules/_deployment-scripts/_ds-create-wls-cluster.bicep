// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string
@secure()
param _artifactsLocationSasToken string = ''

param aksClusterRGName string = ''
param aksClusterName string = ''
param acrName string = ''
param appgwAlias string = 'contoso'
param appPackageUrls array = []
param appReplicas int = 2
param enableCustomSSL bool = false
param enablePV bool = false
param identity object
param location string = 'eastus'
param managedServerPrefix string = 'managed-server'
@secure()
param ocrSSOPSW string
param ocrSSOUser string
param storageAccountName string = 'null'
param utcValue string = utcNow()
@secure()
param wdtRuntimePassword string
param wlsClusterSize int = 5
param wlsCPU string = '200m'
param wlsDomainName string = 'domain1'
param wlsDomainUID string = 'sample-domain1'
param wlsIdentityKeyStoreData string ='null'
@secure()
param wlsIdentityKeyStorePassphrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsIdentityKeyStoreType string = 'PKCS12'
param wlsImageTag string = '12.2.1.4'
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
param wlsPrivateKeyAlias string ='contoso'
@secure()
param wlsPrivateKeyPassPhrase string = newGuid()
param wlsTrustKeyStoreData string = 'null'
@secure()
param wlsTrustKeyStorePassPhrase string = newGuid()
@allowed([
  'JKS'
  'PKCS12'
])
param wlsTrustKeyStoreType string = 'PKCS12'
param wlsUserName string = 'weblogic'

var const_arguments = '${ocrSSOUser} ${ocrSSOPSW} ${aksClusterRGName} ${aksClusterName} ${wlsImageTag} ${acrName} ${wlsDomainName} ${wlsDomainUID} ${wlsUserName} ${wlsPassword} ${wdtRuntimePassword} ${wlsCPU} ${wlsMemory} ${managedServerPrefix} ${appReplicas} ${string(appPackageUrls)} ${resourceGroup().name} ${const_scriptLocation} ${storageAccountName} ${wlsClusterSize} ${enableCustomSSL} ${wlsIdentityKeyStoreData} ${wlsIdentityKeyStorePassphrase} ${wlsIdentityKeyStoreType} ${wlsPrivateKeyAlias} ${wlsPrivateKeyPassPhrase} ${wlsTrustKeyStoreData} ${wlsTrustKeyStorePassPhrase} ${wlsTrustKeyStoreType} ${appgwAlias} ${enablePV} '
var const_commonScript = 'common.sh'
var const_pvTempalte = 'pv.yaml.template'
var const_pvcTempalte = 'pvc.yaml.template'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_genDomainConfigScript= 'genDomainConfig.sh'
var const_setUpDomainScript = 'setupWLSDomain.sh'
var const_utilityScript= 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-wls-cluster-creation'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: '2.15.0'
    arguments: const_arguments
    primaryScriptUri: uri(const_scriptLocation, '${const_setUpDomainScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_genDomainConfigScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pvTempalte}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pvcTempalte}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
