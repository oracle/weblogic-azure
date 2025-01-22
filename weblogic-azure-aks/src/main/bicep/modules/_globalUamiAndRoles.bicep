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

resource keyvaultStoringWLSSSLCerts 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' existing = {
  name: sslKeyVaultName
  scope: resourceGroup(sslKeyVaultResourceGroup)
}

resource keyvaultStoringAppgwCerts 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

module updateKeyvaultStoringWLSSSLCerts '_azure-resoruces/_keyvault/_keyvaultGetListAccessPolicy.bicep' = if (enableCustomSSL && sslConfigurationAccessOption == 'keyVaultStoredConfig') {
  name: 'update-keyvault-storing-wls-ssl-certs-with-getlist-permission'
  scope: resourceGroup(sslKeyVaultResourceGroup)
  params: {
    keyVault: keyvaultStoringWLSSSLCerts
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
  }
}

module updateKeyvaultStoringAppgwCerts '_azure-resoruces/_keyvault/_keyvaultGetListAccessPolicy.bicep' = if (enableAppGWIngress && appGatewayCertificateOption == 'haveKeyVault') {
  name: 'update-keyvault-storing-appgw-certs-with-getlist-permission'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    keyVault: keyvaultStoringAppgwCerts
    principalId: reference(resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', name_deploymentScriptUserDefinedManagedIdentity)).principalId
  }
}

output uamiIdForDeploymentScript string = uamiForDeploymentScript.id
