// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('wlsgw${uniqueString(utcValue)}', 63)
param enableCustomSSL bool = false
param gatewayName string
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param gatewaySslCertName string = 'appGatewaySslCert'
param gatewayTrustedRootCertName string = 'appGatewayTrustedRootCert'
param location string
param noSslCertPsw bool = false
@secure()
param sslCertData string = newGuid()
@secure()
param sslCertPswData string = newGuid()
param staticPrivateFrontentIP string = '10.0.0.1'
@secure()
param trustedRootCertData string = newGuid()
param usePrivateIP bool = false
@description('Tags for the resources.')
param tagsByResource object
param utcValue string = utcNow()

var const_sslCertPsw = (noSslCertPsw) ? '' : sslCertPswData
var name_backendAddressPool = 'myGatewayBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_frontEndPrivateIPConfig = 'appGwPrivateFrontendIp'
var name_httpListener = 'HTTPListener'
var name_httpPort = 'httpport'
var name_httpSetting = 'myHTTPSetting'
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', gatewayName, name_backendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', gatewayName, name_httpSetting)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', gatewayName, name_httpPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', gatewayName, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', gatewayName, name_httpListener)
var ref_publicIPAddress = resourceId('Microsoft.Network/publicIPAddresses', gatewayPublicIPAddressName)
var obj_backendTrustedRootCerts = [
  {
    name: gatewayTrustedRootCertName
    properties: {
      data: trustedRootCertData
    }
  }
]
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

var obj_tagIngress = {
  'managed-by-k8s-ingress': 'true'
}

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: gatewayPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: location
  tags: tagsByResource['Microsoft.Network/publicIPAddresses']
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
}

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@2023-06-01' = {
  name: gatewayName
  location: location
  tags: union(tagsByResource['Microsoft.Network/applicationGateways'], obj_tagIngress)
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslCertificates: [
      {
        name: gatewaySslCertName
        properties: {
          data: sslCertData
          password: const_sslCertPsw
        }
      }
    ]
    trustedRootCertificates: enableCustomSSL ? obj_backendTrustedRootCerts : []
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
          priority: 3
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
output appGatewayId string = wafv2AppGateway.id
output appGatewayName string = gatewayName
output appGatewayURL string = uri(format('http://{0}/', usePrivateIP ? staticPrivateFrontentIP : reference(gatewayPublicIP.id).dnsSettings.fqdn), '')
output appGatewaySecuredURL string = uri(format('https://{0}/', usePrivateIP ? staticPrivateFrontentIP : reference(gatewayPublicIP.id).dnsSettings.fqdn), '')
