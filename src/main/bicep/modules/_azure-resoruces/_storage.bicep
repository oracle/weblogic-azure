// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param location string = 'eastus'
param utcValue string = utcNow()

var const_shareQuota = 5120
var const_sku = 'Standard_LRS'
var name_fileShare = 'weblogic'
var name_storageAccount = 'stg${uniqueString(utcValue)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: name_storageAccount
  location: location
  kind: 'StorageV2'
  sku: {
    name: const_sku
    tier: 'Standard'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
  name: '${storageAccount.name}/default/${name_fileShare}'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: const_shareQuota
    enabledProtocols: 'SMB'
  }
  dependsOn: [
    storageAccount
  ]
}

output storageAccountName string = name_storageAccount
