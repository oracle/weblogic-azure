/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _pidCPUUtilization string = ''
param _pidEnd string = ''
param _pidMemoryUtilization string = ''
param _pidStart string = ''
param _pidWme string = ''

param aksClusterName string 
param aksClusterRGName string
param azCliVersion string

@allowed([
  'cpu'
  'memory'
])
param hpaScaleType string = 'cpu'
param identity object = {}
param location string
param utcValue string = utcNow()
param useHpa bool 
param utilizationPercentage int
param wlsClusterSize int
param wlsDomainUID string
@secure()
param wlsPassword string
param wlsUserName string

var const_namespace = '${wlsDomainUID}-ns'
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfMonitorDataReader = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_azureMonitorAccountName = 'ama${uniqueString(utcValue)}'
var name_kedaUserDefinedManagedIdentity = 'kedauami${uniqueString(utcValue)}'
var name_kedaMonitorDataReaderRoleAssignmentName = guid('${resourceGroup().id}${name_kedaUserDefinedManagedIdentity}')

module pidAutoScalingStart './_pids/_pid.bicep' = {
  name: 'pid-auto-scaling-start'
  params: {
    name: _pidStart
  }
}

module pidCpuUtilization './_pids/_pid.bicep' = if(useHpa && hpaScaleType == 'cpu') {
  name: 'pid-auto-scaling-based-on-cpu-utilization'
  params: {
    name: _pidCPUUtilization
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module pidMemoryUtilization './_pids/_pid.bicep' = if(useHpa && hpaScaleType == 'memory') {
  name: 'pid-auto-scaling-based-on-memory-utilization'
  params: {
    name: _pidMemoryUtilization
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module pidWme './_pids/_pid.bicep' = if(!useHpa) {
  name: 'pid-auto-scaling-based-on-java-metrics'
  params: {
    name: _pidWme
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module hapDeployment '_deployment-scripts/_ds_enable_hpa.bicep' = if(useHpa) {
  name: 'hpa-deployment'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: azCliVersion
    hpaScaleType: hpaScaleType
    identity: identity
    location: location
    utilizationPercentage: utilizationPercentage
    wlsClusterSize: wlsClusterSize
    wlsNamespace: const_namespace
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

resource monitorAccount 'Microsoft.Monitor/accounts@2023-04-03' = if(!useHpa){
  name: name_azureMonitorAccountName
  location: location
  properties: {}
  dependsOn: [
    pidAutoScalingStart
  ]
}

// UAMI for KEDA
resource uamiForKeda 'Microsoft.ManagedIdentity/userAssignedIdentities@${azure.apiVersionForIdentity}' = if(!useHpa){
  name: name_kedaUserDefinedManagedIdentity
  location: location
  dependsOn: [
    pidAutoScalingStart
  ]
}

// Get role resource id
resource monitorDataReaderResourceDefinition 'Microsoft.Authorization/roleDefinitions@${azure.apiVersionForRoleDefinitions}' existing = if(!useHpa){
  name: const_roleDefinitionIdOfMonitorDataReader
}

// Assign Monitor Data Reader role we need the permission to read data.
resource kedaUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = if(!useHpa){
  name: name_kedaMonitorDataReaderRoleAssignmentName
  scope: monitorAccount
  properties: {
    description: 'Assign Monitor Data Reader role role to KEDA Identity '
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_kedaUserDefinedManagedIdentity)).principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: monitorDataReaderResourceDefinition.id
  }
  dependsOn: [
    monitorAccount
    uamiForKeda
  ]
}

module azureMonitorIntegrationDeployment '_deployment-scripts/_ds_enable_prometheus_metrics.bicep' = if(!useHpa){
  name: 'azure-monitor-promethues-keda-deployment'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    amaName: name_azureMonitorAccountName
    azCliVersion: azCliVersion
    identity: identity
    kedaUamiName: name_kedaUserDefinedManagedIdentity
    location: location
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

module pidAutoScalingEnd './_pids/_pid.bicep' = {
  name: 'pid-auto-scaling-end'
  params: {
    name: _pidEnd
  }
  dependsOn: [
    hapDeployment
    azureMonitorIntegrationDeployment
  ]
}

output kedaScalerServerAddress string = useHpa ? '' : azureMonitorIntegrationDeployment.outputs.kedaScalerServerAddress
output base64ofKedaScalerSample string = useHpa ? '' : format('echo -e {0} | base64 -d > scaler.yaml', azureMonitorIntegrationDeployment.outputs.base64ofKedaScalerSample) 
