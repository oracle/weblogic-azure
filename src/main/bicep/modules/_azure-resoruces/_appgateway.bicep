// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@secure()
param appGatewaySSLCertificateData string = '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'
@secure()
param appGatewaySSLCertificatePassword string = 'wlsEng@aug2019'
@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('wlsgw${uniqueString(utcValue)}-${toLower(resourceGroup().name)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param utcValue string = utcNow()

var const_subnetAddressPrefix = '172.16.0.0/28'
var const_virtualNetworkAddressPrefix = '172.16.0.0/24'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
var name_appGatewayCertificate = 'appGwSslCertificate'
var name_appGatewaySubnet = 'appGatewaySubnet'
var name_backendAddressPool = 'myGatewayBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_httpListener = 'HTTPListener'
var name_httpPort = 'httpport'
var name_httpSetting = 'myHTTPSetting'
var name_httpsListener = 'HTTPSListener'
var name_httpsPort = 'httpsport'
var name_nsg = 'nsg${uniqueString(utcValue)}'
var name_virtualNetwork = 'vnet${uniqueString(utcValue)}'
var ref_appGatewaySubnet = resourceId('Microsoft.Network/virtualNetworks/subnets', name_virtualNetwork, name_appGatewaySubnet)
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_backendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
var ref_frontendHTTPSPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpsPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)
var ref_httpsListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpsListener)
var ref_sslCertificate = resourceId('Microsoft.Network/applicationGateways/sslCertificates', name_appGateway, name_appGatewayCertificate)

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
      {
        name: name_httpsPort
        properties: {
          port: 443
        }
      }
    ]
    sslCertificates: [
      {
        name: 'appGwSslCertificate'
        properties: {
          data: appGatewaySSLCertificateData
          password: appGatewaySSLCertificatePassword
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
      {
        name: name_httpsListener
        properties: {
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPSPort
          }
          protocol: 'Https'
          requireServerNameIndication: false
          sslCertificate: {
            id: ref_sslCertificate
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
      {
        name: 'HTTPSRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: ref_httpsListener
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
