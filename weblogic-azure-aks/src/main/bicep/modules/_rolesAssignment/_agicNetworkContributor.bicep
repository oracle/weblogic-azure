/* 
 Copyright (c) 2021, 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param aksClusterName string 
param aksClusterRGName string
param utcValue string = utcNow()

var const_APIVersion = '2020-12-01'
var name_appGwContributorRoleAssignmentName = guid('${resourceGroup().id}${uniqueString(utcValue)}NetworkContributor')
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfVnetContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource aksCluster 'Microsoft.ContainerService/managedClusters@${azure.apiVersionForManagedClusters}' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
}

resource agicUamiRoleAssignment 'Microsoft.Authorization/roleAssignments@${azure.apiVersionForRoleAssignment}' = {
  name: name_appGwContributorRoleAssignmentName
  properties: {
    description: 'Assign Network Contributor role to AGIC Identity '
    principalId: reference(aksCluster.id, const_APIVersion , 'Full').properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', const_roleDefinitionIdOfVnetContributor)
  }
  dependsOn: [
    aksCluster
  ]
}
