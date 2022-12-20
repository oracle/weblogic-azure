/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _pidEnd string = ''
param _pidStart string = ''

@description('Name of an existing AKS cluster.')
param aksClusterName string = ''
param aksClusterRGName string = ''
param aksNodeRGName string = ''
param azCliVersion string = ''
@description('One of the supported database types')
param databaseType string = 'oracle'
@allowed([
  'createOrUpdate'
  'delete'
])
param dbConfigurationType string = 'createOrUpdate'
@description('Determines the transaction protocol (global transaction processing behavior) for the data source.')
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
param dbIdentity object = {}
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database.azure.com:5432/postgres'

param identity object = {}

@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceName string = 'jdbc/contoso'
param location string
param utcValue string = utcNow()
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var const_identityAPIVersion = '2022-01-31-PREVIEW'
// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var const_roleDefinitionIdOfVMContributor = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
var const_podIdentitySelector = 'db-pod-identity' // Do not change this value. 
var name_dbIdentityName = split(items(dbIdentity.userAssignedIdentities)[0].key, '/')[8]
// Azure JDBC plugins, used to generate connection string.
var name_jdbcPlugins = {
  mysql: 'defaultAuthenticationPlugin=com.azure.identity.extensions.jdbc.mysql.AzureMysqlAuthenticationPlugin&authenticationPlugins=com.azure.identity.extensions.jdbc.mysql.AzureMysqlAuthenticationPlugin'
  postgresql: 'authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin'
}
var name_podIdentity = format('{0}-pod-identity-{1}', databaseType, toLower(utcValue))

module pidStart './_pids/_pid.bicep' = {
  name: 'wls-aks-db-start-pid-deployment'
  params: {
    name: _pidStart
  }
}

// Reference: https://learn.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
module dbIdentityVMContributorRoleAssignment '_rolesAssignment/_roleAssignmentinRgScope.bicep' = {
  name: 'assign-db-identity-vm-contributor-role'
  scope: resourceGroup(aksNodeRGName)
  params: {
    identity: dbIdentity
    roleDefinitionId: const_roleDefinitionIdOfVMContributor
  }
}

resource existingAKSCluster 'Microsoft.ContainerService/managedClusters@2021-02-01' existing = {
  name: aksClusterName
  scope: resourceGroup(aksClusterRGName)
}

// Make sure cluster identity has Managed Identity Operator role over db identity
module grantAKSClusterMioRoleOverDBIdentity '_rolesAssignment/_aksClusterMioRoleOverDbIdentity.bicep' = {
  name: 'grant-aks-cluster-mio-role-over-db-identity'
  scope: resourceGroup(split(items(dbIdentity.userAssignedIdentities)[0].key, '/')[4])
  params: {
    clusterIdentityPrincipalId: existingAKSCluster.identity.principalId
    dbIdentityName: name_dbIdentityName
  }
  dependsOn: [
    dbIdentityVMContributorRoleAssignment
    existingAKSCluster
  ]
}

// Reference: https://learn.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
module configAKSPodIdentity '_azure-resoruces/_aksPodIdentity.bicep' = {
  name: 'configure-pod-identity'
  scope: resourceGroup(aksClusterRGName)
  params: {
    aksClusterName: aksClusterName
    dbIdentity: dbIdentity
    namespace: format('{0}-ns', wlsDomainUID)
    podIdentityName: name_podIdentity
    podIdentitySelector: const_podIdentitySelector
    location: location
  }
  dependsOn: [
    grantAKSClusterMioRoleOverDBIdentity
  ]
}

module configDataSource '_deployment-scripts/_ds-datasource-connection.bicep' = {
  name: 'create-update-datasource'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: azCliVersion
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbGlobalTranPro: dbGlobalTranPro
    dbUser: dbUser
    dsConnectionURL: uri(format('{0}&{1}&azure.clientId={2}', dsConnectionURL, name_jdbcPlugins[databaseType], reference(items(dbIdentity.userAssignedIdentities)[0].key, const_identityAPIVersion, 'full').properties.clientId), '')
    enablePswlessConnection: true
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    location: location
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    configAKSPodIdentity
  ]
}

module pidEnd './_pids/_pid.bicep' = {
  name: 'wls-aks-db-end-pid-deployment'
  params: {
    name: _pidEnd
  }
  dependsOn: [
    configDataSource
  ]
}
