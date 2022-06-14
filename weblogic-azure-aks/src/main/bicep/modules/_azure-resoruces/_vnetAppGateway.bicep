// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param location string
param vnetForApplicationGateway object = {
  name: 'wlsaks-app-gateway-vnet'
  resourceGroup: resourceGroup().name
  addressPrefixes: [
    '172.16.0.0/24'
  ]
  addressPrefix: '172.16.0.0/24'
  newOrExisting: 'new'
  subnets: {
    gatewaySubnet: {
      name: 'wlsaks-gateway-subnet'
      addressPrefix: '172.16.0.0/24'
      startAddress: '172.16.0.4'
    }
  }
}
param vnetRGNameForApplicationGateway string
param utcValue string = utcNow()

var const_subnetAddressPrefixes = vnetForApplicationGateway.subnets.gatewaySubnet.addressPrefix
var const_vnetAddressPrefixes = vnetForApplicationGateway.addressPrefixes
var const_newVnet = (vnetForApplicationGateway.newOrExisting == 'new') ? true : false
var name_nsg = 'wlsaks-nsg-${uniqueString(utcValue)}'
var name_subnet = vnetForApplicationGateway.subnets.gatewaySubnet.name
var name_vnet = vnetForApplicationGateway.name

// Get existing VNET.
resource existingVnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = if (!const_newVnet) {
  name: name_vnet
  scope: resourceGroup(vnetForApplicationGateway.resourceGroup)
}

// Get existing subnet.
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' existing = if (!const_newVnet) {
  name: name_subnet
  parent: existingVnet
}

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-08-01' = if (const_newVnet) {
  name: name_nsg
  location: location
  properties: {
    securityRules: [
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
        name: 'ALLOW_APPGW'
      }
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 510
          direction: 'Inbound'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
}

// Create new VNET and subnet.
resource newVnet 'Microsoft.Network/virtualNetworks@2021-08-01' = if (const_newVnet) {
  name: name_vnet
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: const_vnetAddressPrefixes
    }
    subnets: [
      {
        name: name_subnet
        properties: {
          addressPrefix: const_subnetAddressPrefixes
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
  dependsOn: [
    nsg
  ]
}

output subIdForApplicationGateway string = const_newVnet ? resourceId('Microsoft.Network/virtualNetworks/subnets', name_vnet, name_subnet) : existingSubnet.id
// To mitigate ARM-TTK error: Control Named vnetForApplicationGateway must output the resourceGroup property when hideExisting is false
output vnetResourceGroupName string = vnetRGNameForApplicationGateway
