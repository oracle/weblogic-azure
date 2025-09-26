/* 
 Copyright (c) 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/
param _globalResourceNameSuffix string
param aksClusterName string 
param aksClusterRGName string
param azCliVersion string
param identity object = {}
param location string
@description('Tags for the resources.')
param tagsByResource object
param utcValue string = utcNow()
param wlsClusterSize int
param wlsDomainUID string
@secure()
param wlsPassword string
param wlsUserName string

var const_namespace = '${wlsDomainUID}-ns'
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfMonitorDataReader = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_azureMonitorAccountName = 'ama${_globalResourceNameSuffix}'
var name_kedaUserDefinedManagedIdentity = 'kedauami${_globalResourceNameSuffix}'
var name_kedaMonitorDataReaderRoleAssignmentName = guid('${resourceGroup().id}${name_kedaUserDefinedManagedIdentity}${_globalResourceNameSuffix}')

resource monitorAccount 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: name_azureMonitorAccountName
  location: location
  properties: {}
  tags: tagsByResource['Microsoft.Monitor/accounts']
}

// UAMI for KEDA
resource uamiForKeda 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name_kedaUserDefinedManagedIdentity
  location: location
  tags: tagsByResource['Microsoft.ManagedIdentity/userAssignedIdentities']
}

// Get role resource id
resource monitorDataReaderResourceDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: const_roleDefinitionIdOfMonitorDataReader
}

// Assign Monitor Data Reader role we need the permission to read data.
resource kedaUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name_kedaMonitorDataReaderRoleAssignmentName
  scope: monitorAccount
  properties: {
    description: 'Assign Monitor Data Reader role role to KEDA Identity '
    principalId: reference(uamiForKeda.id, '2023-01-31', 'full').properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: monitorDataReaderResourceDefinition.id
  }
  dependsOn: [
    monitorAccount
    uamiForKeda
  ]
}

module azureMonitorIntegrationDeployment '_deployment-scripts/_ds_enable_prometheus_metrics.bicep' = {
  name: 'azure-monitor-promethues-keda-deployment'
  params: {
    _globalResourceNameSuffix: _globalResourceNameSuffix
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    amaName: name_azureMonitorAccountName
    azCliVersion: azCliVersion
    identity: identity
    kedaUamiName: name_kedaUserDefinedManagedIdentity
    location: location
    tagsByResource: tagsByResource
    wlsClusterSize: wlsClusterSize
    wlsDomainUID: wlsDomainUID
    wlsNamespace: const_namespace
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
    workspaceId: monitorAccount.id
  }
  dependsOn: [
    kedaUamiRoleAssignment
  ]
}

output kedaScalerServerAddress string = azureMonitorIntegrationDeployment.outputs.kedaScalerServerAddress
output base64ofKedaScalerSample string = format('echo -e {0} | base64 -d > scaler.yaml', azureMonitorIntegrationDeployment.outputs.base64ofKedaScalerSample) 
