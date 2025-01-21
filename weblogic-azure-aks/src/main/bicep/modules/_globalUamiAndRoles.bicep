/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _globalResourceNameSufix string
param enableCustomSSL bool
@allowed([
  'uploadConfig'
  'keyVaultStoredConfig'
])
param sslConfigurationAccessOption string
param sslKeyVaultName string
param sslKeyVaultResourceGroup string
param enableAppGWIngress bool
@allowed([
  'haveCert'
  'haveKeyVault'
  'generateCert'
])
param appGatewayCertificateOption string
param keyVaultName string
param keyVaultResourceGroup string
param location string
@description('${label.tagsLabel}')
param tagsByResource object
param name_deploymentScriptContributorRoleAssignmentName string = newGuid()

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var name_deploymentScriptUserDefinedManagedIdentity = 'wls-aks-deployment-script-user-defined-managed-itentity-${_globalResourceNameSufix}'
var obj_permission = {
  secrets: [
    'get'
    'list'
  ]
}

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

resource updateKeyvaultStoringWLSSSLCerts 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = if (enableCustomSSL && sslConfigurationAccessOption == 'keyVaultStoredConfig') {
  name: sslKeyVaultName
  resourceGroup: sslKeyVaultResourceGroup
  properties: {
    accessPolicies: [
      {
        objectId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
        tenantId: subscription().tenantId
        permissions: obj_permission
      }
    ]
    enabledForTemplateDeployment: true
  }
}

resource updateKeyvaultStoringAppGwCerts 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' = if (enableAppGWIngress && appGatewayCertificateOption == 'haveKeyVault') {
  name: keyVaultName
  resourceGroup: keyVaultResourceGroup
  properties: {
    accessPolicies: [
      {
        objectId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
        tenantId: subscription().tenantId
        permissions: obj_permission
      }
    ]
    enabledForTemplateDeployment: true
  }
}

output uamiIdForDeploymentScript string = uamiForDeploymentScript.id
