// Copyright (c) 2024, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _globalResourceNameSuffix string
param aksClusterName string
param aksClusterRGName string
param amaName string
param azCliVersion string
param identity object = {}
param kedaUamiName string
param location string
@description('Tags for the resources')
param tagsByResource object
param utcValue string = utcNow()
param wlsClusterSize int
param wlsDomainUID string
param wlsNamespace string
@secure()
param wlsPassword string
param wlsUserName string
param workspaceId string

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_common = loadFileAsBase64('../../../arm/scripts/common.sh')
var base64_enableHpa = loadFileAsBase64('../../../arm/scripts/inline-scripts/enablePrometheusMetrics.sh')
var base64_utility = loadFileAsBase64('../../../arm/scripts/utility.sh')
var const_deploymentName = 'ds-enable-promethues-metrics-${_globalResourceNameSuffix}'
var const_kedaNamespace= 'keda'
var const_kedaSa= 'keda-operator'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: const_deploymentName
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['Microsoft.Resources/deploymentScripts']
  properties: {
    azCliVersion: azCliVersion
    scriptContent: format('{0}\r\n\r\n{1}\r\n\r\n{2}', base64ToString(base64_common), base64ToString(base64_utility), base64ToString(base64_enableHpa))
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
        name: 'AMA_NAME'
        value: amaName
      }
      {
        name: 'AMA_WORKSPACE_ID'
        value: workspaceId
      }
      {
        name: 'CURRENT_RG_NAME'
        value: resourceGroup().name
      }
      {
        name: 'KEDA_NAMESPACE'
        value: const_kedaNamespace
      }
      {
        name: 'KEDA_UAMI_NAME'
        value: kedaUamiName
      }
      {
        name: 'KEDA_SERVICE_ACCOUNT_NAME'
        value: const_kedaSa
      }
      {
        name: 'WLS_CLUSTER_SIZE'
        value: string(wlsClusterSize)
      }
      {
        name: 'WLS_ADMIN_PASSWORD'
        value: wlsPassword
      }
      {
        name: 'WLS_ADMIN_USERNAME'
        value: wlsUserName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
      {
        name: 'WLS_NAMESPACE'
        value: wlsNamespace
      }
      {
        name: 'LOCATION'
        value: location
      }
      {
        name: 'SUBSCRIPTION'
        value: split(subscription().id, '/')[2]
      }
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output kedaScalerServerAddress string = deploymentScript.properties.outputs.kedaScalerServerAddress
output base64ofKedaScalerSample string = deploymentScript.properties.outputs.base64ofKedaScalerSample
