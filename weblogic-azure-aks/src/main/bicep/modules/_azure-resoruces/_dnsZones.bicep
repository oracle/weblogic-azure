@description('Azure DNS Zone name.')
param dnszoneName string

resource dnszoneName_resource 'Microsoft.Network/dnszones@${azure.apiVersionForDNSZone}' = {
  name: dnszoneName
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}
