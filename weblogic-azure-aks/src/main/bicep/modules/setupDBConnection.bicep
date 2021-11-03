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

param identity object

@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceName string = 'jdbc/contoso'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

module pids './_pids/_pid.bicep' = {
  name: 'initialization'
}

module configDataSource './_setupDBConnection.bicep' = {
  name: 'create-update--delete-datasource'
  params:{
    _pidEnd: pids.outputs.dbEnd
    _pidStart: pids.outputs.dbStart
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterName: aksClusterName
    aksClusterRGName: resourceGroup().name
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbGlobalTranPro: dbGlobalTranPro
    dbPassword: dbPassword
    dbUser: dbUser
    dsConnectionURL: dsConnectionURL
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn:[
    pids
  ]
}
