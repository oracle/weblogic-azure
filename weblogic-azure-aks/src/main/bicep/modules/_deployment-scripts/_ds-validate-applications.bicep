// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _globalResourceNameSuffix string

param aksClusterRGName string = ''
param aksClusterName string = ''
param azCliVersion string = ''
param identity object = {}
param location string
@description('Tags for the resources.')
param tagsByResource object
param utcValue string = utcNow()
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var const_pyCheckAppStatusScript = 'checkApplicationStatus.py'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_validateAppScript= 'validateApplications.sh'
var const_utilityScript= 'utility.sh'
var const_commonScript= 'common.sh'


resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ds-wls-validate-applications-${_globalResourceNameSuffix}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['Microsoft.Resources/deploymentScripts']
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'AKS_RESOURCE_GROUP_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_NAME'
        value: aksClusterName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
      {
        name: 'WLS_DOMAIN_USER'
        value: wlsUserName
      }
      {
        name: 'WLS_DOMAIN_SHIBBOLETH'
        secureValue: wlsPassword
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_validateAppScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pyCheckAppStatusScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
