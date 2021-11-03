// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _artifactsLocation string
@secure()
param _artifactsLocationSasToken string = ''

param aksClusterName string 
param aksClusterRGName string
param databaseType string = 'oracle'
param dbConfigurationType string
param dbDriverName string = 'org.contoso.Driver'
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@secure()
param dbPassword string = newGuid()
param dbTestTableName string = 'Null'
param dbUser string
param dsConnectionURL string
param identity object
param jdbcDataSourceName string
param utcValue string = utcNow()
param wlsDomainUID string = 'sample-domain1'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var const_arguments = '${aksClusterRGName} ${aksClusterName} ${databaseType} ${dbPassword} ${dbUser} "${dsConnectionURL}" ${jdbcDataSourceName} ${wlsDomainUID} ${wlsUserName} ${wlsPassword} ${dbConfigurationType}'
var const_azcliVersion='2.15.0'
var const_commonScript = 'common.sh'
var const_datasourceScript='setupDBConnections.sh'
var const_datasourceModelScript='genDatasourceModel.sh'
var const_dbUtilityScript='dbUtility.sh'
var const_invokeSetupDBConnectionsScript='invokeSetupDBConnections.sh'
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var const_utilityScript= 'utility.sh'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-wls-db-connection'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    arguments: const_arguments
    environmentVariables: [
      {
        name: 'DB_DRIVER_NAME'
        value:  dbDriverName
      }
      {
        name: 'GLOBAL_TRANSATION_PROTOCOL'
        value:  dbGlobalTranPro
      }
      {
        name: 'TEST_TABLE_NAME'
        value:  dbTestTableName
      }
    ]
    primaryScriptUri: uri(const_scriptLocation, '${const_invokeSetupDBConnectionsScript}${_artifactsLocationSasToken}')
    supportingScriptUris: [
      uri(const_scriptLocation, '${const_datasourceScript}${_artifactsLocationSasToken}')
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
