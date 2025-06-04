// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param acrName string
param location string
@description('${label.tagsLabel}')
param tagsByResource object

resource registries 'Microsoft.ContainerRegistry/registries@${azure.apiVersionForContainerRegistries}' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
  tags: tagsByResource['${identifier.registries}']
}

output acrName string = acrName
