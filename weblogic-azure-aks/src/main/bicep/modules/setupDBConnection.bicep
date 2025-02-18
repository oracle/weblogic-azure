/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
 
Description
  - This script is to confige DB connection in an existing WebLogic Cluster.

Pre-requisites
  - There is at least one WebLogic cluster running on Azure Kubernetes Service (AKS), the cluster must be deployed using Azure WebLoigc on AKS marketplace offer.
  - Azure CLI with bicep installed.

Parameters
  - _artifactsLocation: Script location.
  - aksClusterName: Name of the AKS instance that runs the WebLogic cluster.
  - databaseType: One of the supported database types.
  - dbConfigurationType: 'createOrUpdate' or 'delete'
    - createOrUpdate: create a new data source connection, or update an existing data source connection. 
    - delete: delete an existing data source connection
  - dbPassword: Password for Database
  - dbGlobalTranPro: Determines the transaction protocol (global transaction processing behavior) for the data source..
  - dbUser: User id of Database
  - dsConnectionURL: JDBC Connection String
  - identity: Azure user managed identity used, make sure the identity has permission to create/update/delete Azure resources. It's recommended to assign "Contributor" role.
  - jdbcDataSourceName: JNDI Name for JDBC Datasource.
  - wlsDomainUID: UID of the domain that you are going to update. Make sure it's the same with the initial cluster deployment.

Build and run
  - Run command `bicep build setupDBConnection.bicep`, you will get built ARM template setupDBConnection.json.
  - Prepare parameters file parameters.json
  - Run command `az deployment group create -f setupDBConnection.json -p parameters.json -g <your-resource-group>`
*/

param _artifactsLocation string = 'https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/arm/'
@secure()
param _artifactsLocationSasToken string = ''

@description('Name of an existing AKS cluster.')
param aksClusterName string = ''
@allowed([
  'oracle'
  'postgresql'
  'sqlserver'
  'mysql'
  'otherdb'
])
@description('One of the supported database types')
param databaseType string = 'oracle'
@allowed([
  'createOrUpdate'
  'delete'
])
@description('createOrUpdate: create a new data source connection, or update an existing data source connection. delete: delete an existing data source connection')
param dbConfigurationType string = 'createOrUpdate'
@description('Determines the transaction protocol (global transaction processing behavior) for the data source.')
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@secure()
@description('Password for Database')
param dbPassword string = newGuid()
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database.azure.com:5432/postgres'

param identity object = {}

@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceName string = 'jdbc/contoso'
@description('tags for the resources')
param tagsByResource object = {}
param utcValue string = utcNow()
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

// This template is used for post deployment, hard code the CLI version with a variable.
var const_azCliVersion = '2.33.1'
var _objTagsByResource = {
  'Microsoft.Monitor/accounts': contains(tagsByResource, 'Microsoft.Monitor/accounts') ? tagsByResource['Microsoft.Monitor/accounts'] : json('{}')
  'Microsoft.ContainerService/managedClusters': contains(tagsByResource, 'Microsoft.ContainerService/managedClusters') ? tagsByResource['Microsoft.ContainerService/managedClusters'] : json('{}')
  'Microsoft.Network/applicationGateways': contains(tagsByResource, 'Microsoft.Network/applicationGateways') ? tagsByResource['Microsoft.Network/applicationGateways'] : json('{}')
  'Microsoft.ContainerRegistry/registries': contains(tagsByResource, 'Microsoft.ContainerRegistry/registries') ? tagsByResource['Microsoft.ContainerRegistry/registries'] : json('{}')
  'Microsoft.Compute/virtualMachines': contains(tagsByResource, 'Microsoft.Compute/virtualMachines') ? tagsByResource['Microsoft.Compute/virtualMachines'] : json('{}')
  'Virtual machine extension': contains(tagsByResource, 'Virtual machine extension') ? tagsByResource['Virtual machine extension'] : json('{}')
  'Microsoft.Network/virtualNetworks': contains(tagsByResource, 'Microsoft.Network/virtualNetworks') ? tagsByResource['Microsoft.Network/virtualNetworks'] : json('{}')
  'Microsoft.Network/networkInterfaces': contains(tagsByResource, 'Microsoft.Network/networkInterfaces') ? tagsByResource['Microsoft.Network/networkInterfaces'] : json('{}')
  'Microsoft.Network/networkSecurityGroups': contains(tagsByResource, 'Microsoft.Network/networkSecurityGroups') ? tagsByResource['Microsoft.Network/networkSecurityGroups'] : json('{}')
  'Microsoft.Network/publicIPAddresses': contains(tagsByResource, 'Microsoft.Network/publicIPAddresses') ? tagsByResource['Microsoft.Network/publicIPAddresses'] : json('{}')
  'Microsoft.Storage/storageAccounts': contains(tagsByResource, 'Microsoft.Storage/storageAccounts') ? tagsByResource['Microsoft.Storage/storageAccounts'] : json('{}')
  'Microsoft.KeyVault/vaults': contains(tagsByResource, 'Microsoft.KeyVault/vaults') ? tagsByResource['Microsoft.KeyVault/vaults'] : json('{}')
  'Microsoft.ManagedIdentity/userAssignedIdentities': contains(tagsByResource, 'Microsoft.ManagedIdentity/userAssignedIdentities') ? tagsByResource['Microsoft.ManagedIdentity/userAssignedIdentities'] : json('{}')
  'Microsoft.Network/dnszones': contains(tagsByResource, 'Microsoft.Network/dnszones') ? tagsByResource['Microsoft.Network/dnszones'] : json('{}')
  'Microsoft.OperationalInsights/workspaces': contains(tagsByResource, 'Microsoft.OperationalInsights/workspaces') ? tagsByResource['Microsoft.OperationalInsights/workspaces'] : json('{}')
  'Microsoft.Resources/deploymentScripts': contains(tagsByResource, 'Microsoft.Resources/deploymentScripts') ? tagsByResource['Microsoft.Resources/deploymentScripts'] : json('{}')
}

module pids './_pids/_pid.bicep' = {
  name: 'initialization'
}

module configDataSource './_setupDBConnection.bicep' = {
  name: 'create-update-delete-datasource'
  params:{
    _pidEnd: pids.outputs.dbEnd
    _pidOtherDb: pids.outputs.otherDb
    _pidStart: pids.outputs.dbStart
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _globalResourceNameSuffix: uniqueString(utcValue)
    aksClusterName: aksClusterName
    aksClusterRGName: resourceGroup().name
    azCliVersion: const_azCliVersion
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbGlobalTranPro: dbGlobalTranPro
    dbPassword: dbPassword
    dbUser: dbUser
    dsConnectionURL: dsConnectionURL
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    location: resourceGroup().location
    tagsByResource: _objTagsByResource
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn:[
    pids
  ]
}
