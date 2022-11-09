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
param dbIdentity object
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

var const_APIVersion = '2022-01-31-PREVIEW'
var const_podIdentityName = 'db-pod-identity' // do not change the value
var const_roleDefinitionIdOfVMContributor = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
var name_vmContributorRoleAssignmentName = guid('${resourceGroup().id}${utcValue}')
var name_jdbcPlugins = {
  mysql: 'defaultAuthenticationPlugin=com.azure.identity.providers.mysql.AzureIdentityMysqlAuthenticationPlugin&authenticationPlugins=com.azure.identity.providers.mysql.AzureIdentityMysqlAuthenticationPlugin'
}

module pidStart './_pids/_pid.bicep' = {
  name: 'wls-aks-db-start-pid-deployment'
  params: {
    name: _pidStart
  }
}

module dbUamiRoleAssignment '_rolesAssignment/_roleAssignmentinRgScope.bicep' = {
  name: name_vmContributorRoleAssignmentName
  scope: resourceGroup(aksNodeRGName)
  params: {
    principalId: reference(items(dbIdentity.userAssignedIdentities)[0].key, const_APIVersion, 'full').properties.clientId
    roleDefinitionId: const_roleDefinitionIdOfVMContributor
  }
}

module configPodIdentity '_deployment-scripts/_ds-create-pod-identity.bicep' = {
  name: 'create-pod-identity-for-db-connection'
  params: {
    aadPodIdentityName: const_podIdentityName
    aadPodIdentityNameSpace: format('{0}-ns', wlsDomainUID)
    aadPodIdentityResourceId: items(dbIdentity.userAssignedIdentities)[0].key
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    azCliVersion: azCliVersion
    identity: identity
    location: location
  }
  dependsOn: [
    dbUamiRoleAssignment
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
    dbPassword: ''
    dbUser: dbUser
    dsConnectionURL: format('{0}&{1}&azure.clientId={2}', dsConnectionURL, name_jdbcPlugins[databaseType], reference(items(dbIdentity.userAssignedIdentities)[0].key, const_APIVersion, 'full').properties.clientId)
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    location: location
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    configPodIdentity
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
