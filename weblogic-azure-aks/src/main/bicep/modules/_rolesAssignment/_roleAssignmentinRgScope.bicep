/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

/*
Description: assign roles cross resource group.
Usage:
  module roleAssignment '_roleAssignmentinRgScope.bicep' = {
    name: 'assign-role'
    scope: resourceGroup(<your-resource-group-name)
    params: {
      roleDefinitionId: roleDefinitionId
      principalId: principalId
    }
  }
*/

param _globalResourceNameSuffix string
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
param roleDefinitionId string = ''
param identity object = {}

var const_identityAPIVersion = '2022-01-31-PREVIEW'
var name_roleAssignmentName = guid('${subscription().id}${_globalResourceNameSuffix}Role assignment in resource group scope')

// Get role resource id
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@${azure.apiVersionForRoleDefinitions}' existing = {
  name: roleDefinitionId
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = {
  name: name_roleAssignmentName
  properties: {
    description: 'Assign resource group scope role to User Assigned Managed Identity '
    principalId: reference(items(identity.userAssignedIdentities)[0].key, const_identityAPIVersion, 'full').properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
