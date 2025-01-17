// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _globalResourceNameSufix string

param aksClusterRGName string = ''
param aksClusterName string = ''
param azCliVersion string = ''
param identity object = {}
param location string
@description('${label.tagsLabel}')
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


resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-wls-validate-applications-${_globalResourceNameSufix}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['${identifier.deploymentScripts}']
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
        name: 'WLS_DOMAIN_PASSWORD'
        secureValue: wlsPassword
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_validateAppScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_pyCheckAppStatusScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
