/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

/*
Description: assign roles cross resource group.
Usage:
  module roleAssignment '_roleAssignmentinSubscription.bicep' = {
    name: 'assign-role'
    scope: resourceGroup(<your-resource-group-name)
    params: {
      roleDefinitionId: roleDefinitionId
      principalId: principalId
    }
  }
*/

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
param roleDefinitionId string = ''
param principalId string = ''
param utcValue string = utcNow()

var name_roleAssignmentName = guid('${subscription().id}${principalId}${utcValue}Role assignment in resource group scope')

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: roleDefinitionId
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name_roleAssignmentName
  properties: {
    description: 'Assign resource group scope role to User Assigned Managed Identity '
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
