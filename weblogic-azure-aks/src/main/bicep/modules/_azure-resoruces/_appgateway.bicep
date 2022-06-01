// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('wlsgw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string
param location string
param usePrivateIP bool = false
param utcValue string = utcNow()

var const_capability = 2
// usedto mitigate ARM template error: defined multiple times in a template
var name_appGateway1 = 'appgw1${uniqueString(utcValue)}'
var name_appGateway2 = 'appgw2${uniqueString(utcValue)}'
var name_appGateway = usePrivateIP ? name_appGateway1 : name_appGateway2
var name_appGatewayPublicBaisc = format('{0}{1}', gatewayPublicIPAddressName, 'basic')
var name_backendAddressPool = 'myGatewayBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_frontEndPrivateIPConfig = 'appGwPrivateFrontendIp'
var name_httpListener = 'HTTPListener'
var name_httpPort = 'httpport'
var name_httpSetting = 'myHTTPSetting'
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_backendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2020-07-01' = if (!usePrivateIP) {
  name: gatewayPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
}

resource gatewayPublicIP2 'Microsoft.Network/publicIPAddresses@2020-07-01' = if (usePrivateIP) {
  name: name_appGatewayPublicBaisc
  sku: {
    name: 'Basic'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
}

// https://docs.microsoft.com/en-us/azure/application-gateway/configure-application-gateway-with-private-frontend-ip
resource standardAppGateway 'Microsoft.Network/applicationGateways@2020-07-01' = if (usePrivateIP) {
  name: name_appGateway1
  location: location
  tags: {
    'managed-by-k8s-ingress': 'true'
  }
  properties: {
    sku: {
      name: 'Standard_Medium'
      tier: 'Standard'
      capacity: const_capability
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: name_frontEndPrivateIPConfig
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
      {
        name: name_frontEndIPConfig
        properties: {
          publicIPAddress: {
            id: gatewayPublicIP2.id
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
  }
  dependsOn: [
    gatewayPublicIP2
  ]
}

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@2020-07-01' = if (!usePrivateIP) {
  name: name_appGateway2
  location: location
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
            id: gatewaySubnetId
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
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 3
    }
  }
  dependsOn: [
    gatewayPublicIP
  ]
}

output appGatewayAlias string = usePrivateIP ? standardAppGateway.properties.frontendIPConfigurations[0].properties.privateIPAddress : reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewayName string = name_appGateway
output appGatewayURL string = format('http://{0}', usePrivateIP ? standardAppGateway.properties.frontendIPConfigurations[0].properties.privateIPAddress : reference(gatewayPublicIP.id).dnsSettings.fqdn)
output appGatewaySecuredURL string = format('https://{0}', usePrivateIP ? standardAppGateway.properties.frontendIPConfigurations[0].properties.privateIPAddress : reference(gatewayPublicIP.id).dnsSettings.fqdn)
