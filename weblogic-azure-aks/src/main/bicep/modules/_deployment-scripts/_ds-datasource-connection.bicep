// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _globalResourceNameSuffix string

param aksClusterName string 
param aksClusterRGName string
param databaseType string = 'oracle'
param azCliVersion string = ''
param dbConfigurationType string = 'createOrUpdate'
param dbDriverName string = 'org.contoso.Driver'
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@secure()
param dbPassword string = newGuid()
param dbTestTableName string = 'Null'
param dbUser string
param dsConnectionURL string
param enablePswlessConnection bool = false
param identity object = {}
param jdbcDataSourceName string
param location string
@description('${label.tagsLabel}')
param tagsByResource object
param utcValue string = utcNow()
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var const_commonScript = 'common.sh'
var const_datasourceScript='setupDBConnections.sh'
var const_datasourceModelScript='genDatasourceModel.sh'
var const_dbUtilityScript='dbUtility.sh'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_utilityScript= 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-wls-db-connection-${_globalResourceNameSuffix}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['${identifier.deploymentScripts}']
  properties: {
    azCliVersion: azCliVersion
    environmentVariables: [
      {
        name: 'AKS_RESOURCE_GROUP_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_NAME'
        value: aksClusterName
      }
      {
        name: 'DATABASE_TYPE'
        value: databaseType
      }
      {
        name: 'DB_CONFIGURATION_TYPE'
        value: dbConfigurationType
      }
      {
        name: 'DB_PASSWORD'
        secureValue: dbPassword
      }
      {
        name: 'DB_USER'
        value: dbUser
      }
      {
        name: 'DB_CONNECTION_STRING'
        value: dsConnectionURL
      }
      {
        name: 'DB_DRIVER_NAME'
        value:  dbDriverName
      }
      {
        name: 'ENABLE_PASSWORDLESS_CONNECTION'
        value: string(enablePswlessConnection)
      }
      {
        name: 'GLOBAL_TRANSATION_PROTOCOL'
        value:  dbGlobalTranPro
      }
      {
        name: 'JDBC_DATASOURCE_NAME'
        value: jdbcDataSourceName
      }
      {
        name: 'TEST_TABLE_NAME'
        value:  dbTestTableName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
      {
        name: 'WLS_DOMAIN_USER'
        value: wlsUserName
      }
      {
        name: 'WLS_DOMAIN_PASSWORD'
        secureValue: wlsPassword
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_datasourceScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_commonScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_utilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_dbUtilityScript}${_artifactsLocationSasToken}')
      uri(const_scriptLocation, '${const_datasourceModelScript}${_artifactsLocationSasToken}')
    ]
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}
