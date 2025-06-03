@description('Azure DNS Zone name.')
param dnszoneName string
@description('Tags for the resources')
param tagsByResource object

resource dnszoneName_resource 'Microsoft.Network/dnszones@2023-07-01-preview' = {
  name: dnszoneName
  location: 'global'
  tags: tagsByResource['Microsoft.Network/dnszones']
  properties: {
    zoneType: 'Public'
  }
}
