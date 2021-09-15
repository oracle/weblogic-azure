/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _artifactsLocation string = ''
@secure()
param _artifactsLocationSasToken string = ''
param _pidEnd string = ''
param _pidStart string = ''

@description('Name of an existing AKS cluster.')
param aksClusterName string = ''
param aksClusterRGName string = ''
@description('One of the supported database types')
param databaseType string = 'oracle'
@allowed([
  'createOrUpdate'
  'delete'
])
param dbConfigurationType string = 'createOrUpdate'
@description('Datasource driver name')
param dbDriverName string = 'org.contoso.Driver'
@description('Determines the transaction protocol (global transaction processing behavior) for the data source.')
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@description('Password for Database')
param dbPassword string = newGuid()
@description('The name of the database table to use when testing physical database connections. This name is required when you specify a Test Frequency and enable Test Reserved Connections.')
param dbTestTableName string = 'Null'
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

module pidStart './_pids/_pid.bicep' = {
  name: 'wls-aks-db-start-pid-deployment'
  params: {
    name: _pidStart
  }
}

module configDataSource '_deployment-scripts/_ds-datasource-connection.bicep' = {
  name: 'create-update-datasource'
  params:{
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbDriverName: dbDriverName
    dbGlobalTranPro: dbGlobalTranPro
    dbPassword: dbPassword
    dbTestTableName: dbTestTableName
    dbUser: dbUser
    dsConnectionURL: dsConnectionURL
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn:[
    pidStart
  ]
}


module pidEnd './_pids/_pid.bicep' = {
  name: 'wls-aks-db-end-pid-deployment'
  params: {
    name: _pidEnd
  }
  dependsOn:[
    configDataSource
  ]
}
