// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

/* This script is to apply Guaranteed Qos by specifying resources.limits
*  To solve pod evicted issue in Oracle WebLogic 14.1.1.0.
*  The script will promote CPU request and limit to 500m if the CPU request is less than 500m.
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''

param aksClusterName string = ''
param aksClusterRGName string = ''

param identity object
param location string
param utcValue string = utcNow()
param wlsClusterName string = 'cluster-1'
param wlsDomainUID string = 'sample-domain1'

var const_azcliVersion = '2.15.0'
var const_constScript = 'common.sh'
var const_deploymentName = 'ds-apply-guaranteed-qos'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_updateQosScript = 'applyGuaranteedQos.sh'
var const_utilityScript = 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'AKS_CLUSTER_RESOURCEGROUP_NAME'
        value: aksClusterRGName
      }
      {
        name: 'WLS_CLUSTER_NAME'
        value: wlsClusterName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_updateQosScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_constScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output wlsVersion string = string(reference(const_deploymentName).outputs.wlsVersion)
output qualityofService string = string(reference(const_deploymentName).outputs.qualityofService)
