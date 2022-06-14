// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('wlsgw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param location string
param staticPrivateFrontentIP string = '10.0.0.1'
param usePrivateIP bool = false
param utcValue string = utcNow()

var name_appGateway = 'appgw${uniqueString(utcValue)}'
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
var ref_publicIPAddress = resourceId('Microsoft.Network/publicIPAddresses', gatewayPublicIPAddressName)
var obj_frontendIPConfigurations1 = [
  {
    name: name_frontEndIPConfig
    properties: {
      publicIPAddress: {
        id: ref_publicIPAddress
      }
    }
  }
]
var obj_frontendIPConfigurations2 = [
  {
    name: name_frontEndIPConfig
    properties: {
      publicIPAddress: {
        id: ref_publicIPAddress
      }
    }
  }
  {
    name: name_frontEndPrivateIPConfig
    properties: {
      privateIPAllocationMethod: 'Static'
      privateIPAddress: staticPrivateFrontentIP
      subnet: {
        id: gatewaySubnetId
      }
    }
  }
]

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2020-07-01' = {
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

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@2020-07-01' = {
  name: name_appGateway
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
    frontendIPConfigurations: usePrivateIP ? obj_frontendIPConfigurations2 : obj_frontendIPConfigurations1
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

output appGatewayAlias string = usePrivateIP ? staticPrivateFrontentIP : reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewayName string = name_appGateway
output appGatewayURL string = format('http://{0}/', usePrivateIP ? staticPrivateFrontentIP : reference(gatewayPublicIP.id).dnsSettings.fqdn)
output appGatewaySecuredURL string = format('https://{0}/', usePrivateIP ? staticPrivateFrontentIP : reference(gatewayPublicIP.id).dnsSettings.fqdn)
