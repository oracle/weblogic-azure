/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

/*
Description: assign roles cross resource group.
Usage:
  module roleAssignment '_roleAssignmentinSubscription.bicep' = {
    name: 'assign-role'
    scope: subscription()
    params: {
      roleDefinitionId: roleDefinitionId
      principalId: principalId
    }
  }
*/

targetScope = 'subscription'

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
param roleDefinitionId string = ''
param principalId string = ''

var name_roleAssignmentName = guid('${subscription().id}${principalId}Role assignment in subscription scope')

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@${azure.apiVersionForRoleDefinitions}' existing = {
  name: roleDefinitionId
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = {
  name: name_roleAssignmentName
  properties: {
    description: 'Assign subscription scope role to User Assigned Managed Identity '
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
