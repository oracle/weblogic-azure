@description('Azure DNS Zone name.')
param dnszoneName string

resource dnszoneName_resource 'Microsoft.Network/dnszones@2020-06-01' = {
  name: dnszoneName
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}
