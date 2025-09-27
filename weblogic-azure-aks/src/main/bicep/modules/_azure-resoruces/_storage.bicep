// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param fileShareName string
param location string
param storageAccountName string = 'stg-contoso'
@description('${label.tagsLabel}')
param tagsByResource object
param utcValue string = utcNow()

var const_shareQuota = 5120
var const_sku = 'Standard_LRS'
var obj_extraTag = {
  'created-by-azure-weblogic': utcValue
}

resource storageAccount 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  tags: union(tagsByResource['${identifier.storageAccounts}'], obj_extraTag)
  sku: {
    name: const_sku
    tier: 'Standard'
  }
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
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

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@${azure.apiVersionForStorageFileService}' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: const_shareQuota
    enabledProtocols: 'SMB'
  }
  dependsOn: [
    storageAccount
  ]
}
