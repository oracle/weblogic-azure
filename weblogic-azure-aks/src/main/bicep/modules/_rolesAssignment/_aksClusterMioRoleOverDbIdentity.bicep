/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

/*
Description: assign roles cross resource group.
Usage:
  module roleAssignment '_roleAssignmentinSubscription.bicep' = {
    name: 'assign-role'
    scope: resourceGroup(<db-identity-resource-group-name)
    params: {
      dbIdentityName: dbIdentityName
      dbIdentityPrincipalId: dbIdentityPrincipalId
    }
  }
*/

param clusterIdentityPrincipalId string = ''
param dbIdentityName string = ''

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfManagedIdentityOperator = 'f1a07417-d97a-45cb-824c-7a7467783830'
var name_roleAssignmentName = guid('${subscription().id}${clusterIdentityPrincipalId}Role assignment in resource scope')

resource dbIdentityResource 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  name: dbIdentityName
}

// Get role resource id in subscription
resource roleResourceDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: const_roleDefinitionIdOfManagedIdentityOperator
}

// Assign role
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name_roleAssignmentName
  scope: dbIdentityResource
  properties: {
    description: 'Assign Managed Identity Operator role to AKS Cluster over DB Identity '
    principalId: clusterIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleResourceDefinition.id
  }
}

output roleId string = roleResourceDefinition.id
