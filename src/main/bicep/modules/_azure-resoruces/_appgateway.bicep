// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('wlsgw${uniqueString(utcValue)}-${toLower(resourceGroup().name)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param utcValue string = utcNow()

var const_subnetAddressPrefix = '172.16.0.0/28'
var const_virtualNetworkAddressPrefix = '172.16.0.0/24'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
var name_appGatewaySubnet = 'appGatewaySubnet'
var name_backendAddressPool = 'myGatewayBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_httpListener = 'HTTPListener'
var name_httpPort = 'httpport'
var name_httpSetting = 'myHTTPSetting'
var name_nsg = 'nsg${uniqueString(utcValue)}'
var name_virtualNetwork = 'vnet${uniqueString(utcValue)}'
var ref_appGatewaySubnet = resourceId('Microsoft.Network/virtualNetworks/subnets', name_virtualNetwork, name_appGatewaySubnet)
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_backendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: name_nsg
  location: resourceGroup().location
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
          sourcePortRanges: []
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: name_virtualNetwork
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        const_virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: name_appGatewaySubnet
        properties: {
          addressPrefix: const_subnetAddressPrefix
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

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
  name: gatewayPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2020-07-01' = {
  name: name_appGateway
  location: resourceGroup().location
  tags: {
    'managed-by-k8s-ingress': 'true'
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: ref_appGatewaySubnet
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: name_frontEndIPConfig
        properties: {
          publicIPAddress: {
            id: gatewayPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: name_httpPort
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'myGatewayBackendPool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    httpListeners: [
      {
        name: name_httpListener
        properties: {
          protocol: 'Http'
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPPort
          }
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: name_httpSetting
        properties: {
          port: 80
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'HTTPRoutingRule'
        properties: {
          httpListener: {
            id: ref_httpListener
          }
          backendAddressPool: {
            id: ref_backendAddressPool
          }
          backendHttpSettings: {
            id: ref_backendHttpSettings
          }
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 3
    }
  }
  dependsOn: [
    vnet
  ]
}

output appGatewayAlias string = reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewayName string = name_appGateway
output appGatewayURL string = 'http://${reference(gatewayPublicIP.id).dnsSettings.fqdn}/'
output appGatewaySecuredURL string = 'https://${reference(gatewayPublicIP.id).dnsSettings.fqdn}/'
output vnetName string = name_virtualNetwork
