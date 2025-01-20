/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _globalResourceNameSufix string
param location string
@description('${label.tagsLabel}')
param tagsByResource object
param name_deploymentScriptContributorRoleAssignmentName string = newGuid()

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_deploymentScriptUserDefinedManagedIdentity = 'wls-aks-deployment-script-user-defined-managed-itentity-${_globalResourceNameSufix}'


// UAMI for deployment script
resource uamiForDeploymentScript 'Microsoft.ManagedIdentity/userAssignedIdentities@${azure.apiVersionForIdentity}' = {
  name: name_deploymentScriptUserDefinedManagedIdentity
  location: location
  tags: tagsByResource['${identifier.userAssignedIdentities}']
}

// Assign Contributor role in subscription scope, we need the permission to get/update resource cross resource group.
module deploymentScriptUAMICotibutorRoleAssignment '_rolesAssignment/_roleAssignmentinSubscription.bicep' = {
  name: name_deploymentScriptContributorRoleAssignmentName
  scope: subscription()
  params: {
    roleDefinitionId: const_roleDefinitionIdOfContributor
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
  }
}

output uamiIdForDeploymentScript string = uamiForDeploymentScript.id
