@description('Azure DNS Zone name.')
param dnszoneName string

@description('Location for all resources.')
param location string

resource dnszoneName_resource 'Microsoft.Network/dnszones@2018-05-01' = {
  name: dnszoneName
  location: location
  properties: {
    zoneType: 'Public'
  }
}
