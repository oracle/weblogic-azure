/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param aksClusterName string 
param aksClusterRGName string
param utcValue string = utcNow()

var const_APIVersion = '2020-12-01'
var name_appGwContributorRoleAssignmentName = guid('${resourceGroup().id}${utcValue}ForApplicationGateway')
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-09-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
}

resource agicUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: name_appGwContributorRoleAssignmentName
  properties: {
    description: 'Assign Resource Group Contributor role to User Assigned Managed Identity '
    principalId: reference(aksCluster.id, const_APIVersion , 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfContributor)
  }
  dependsOn: [
    aksCluster
  ]
}
