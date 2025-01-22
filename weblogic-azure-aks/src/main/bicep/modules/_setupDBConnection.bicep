/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _globalResourceNameSufix string = uniqueString(utcNow())
param _pidEnd string = ''
param _pidStart string = ''
param _pidOtherDb string = ''

@description('Name of an existing AKS cluster.')
param aksClusterName string = ''
param aksClusterRGName string = ''
param azCliVersion string = ''
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
@secure()
@description('Password for Database')
param dbPassword string = newGuid()
@description('The name of the database table to use when testing physical database connections. This name is required when you specify a Test Frequency and enable Test Reserved Connections.')
param dbTestTableName string = 'Null'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database.azure.com:5432/postgres'

param identity object = {}

@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceName string = 'jdbc/contoso'
param location string
@description('${label.tagsLabel}')
param tagsByResource object = {}
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

module pidOtherDb './_pids/_pid.bicep' = if (databaseType == 'otherdb') {
  name: 'wls-other-db-pid-deployment'
  params: {
    name: _pidOtherDb
  }
}

module configDataSource '_deployment-scripts/_ds-datasource-connection.bicep' = {
  name: 'create-update-datasource'
  params:{
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _globalResourceNameSufix: _globalResourceNameSufix
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: azCliVersion
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
    location: location
    tagsByResource: tagsByResource
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn:[
    pidStart
    pidOtherDb
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
