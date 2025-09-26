// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''

param aksClusterRGName string = ''
param aksClusterName string = ''
param acrName string = ''
param appPackageUrls array = []
param appPackageFromStorageBlob object = {
  storageAccountName: 'stg-contoso'
  containerName: 'container-contoso'
}
param azCliVersion string = ''
param identity object = {}
param isSSOSupportEntitled bool
param location string

@secure()
param ocrSSOPSW string
param ocrSSOUser string

param utcValue string = utcNow()
param wlsDomainName string = 'domain1'
param wlsDomainUID string = 'sample-domain1'
param wlsImageTag string = '12.2.1.4'
param userProvidedImagePath string = 'null'
param useOracleImage bool = true

var const_buildDockerImageScript='createVMAndBuildImage.sh'
var const_commonScript = 'common.sh'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_updateAppScript= 'updateApplications.sh'
var const_utilityScript= 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ds-wls-update-applications-${uniqueString(utcValue)}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
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
        name: 'CURRENT_RESOURCEGROUP_NAME'
        value: resourceGroup().name
      }
      {
        name: 'ORACLE_ACCOUNT_ENTITLED'
        value: string(isSSOSupportEntitled)
      }
      {
        name: 'ORACLE_ACCOUNT_NAME'
        value: ocrSSOUser
      }
      {
        name: 'ORACLE_ACCOUNT_SHIBBOLETH'
        secureValue: ocrSSOPSW
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: appPackageFromStorageBlob.storageAccountName
      }
      {
        name: 'STORAGE_ACCOUNT_CONTAINER_NAME'
        value: appPackageFromStorageBlob.containerName
      }
      {
        name: 'SCRIPT_LOCATION'
        value: const_scriptLocation
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
        name: 'WLS_APP_PACKAGE_URLS'
        value: string(appPackageUrls)
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
      
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_updateAppScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_buildDockerImageScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output image string = deploymentScript.properties.outputs.image
