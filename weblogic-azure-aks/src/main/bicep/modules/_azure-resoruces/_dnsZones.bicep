@description('Azure DNS Zone name.')
param dnszoneName string
@description('${label.tagsLabel}')
param tagsByResource object

resource dnszoneName_resource 'Microsoft.Network/dnszones@${azure.apiVersionForDNSZone}' = {
  name: dnszoneName
  location: 'global'
  tags: tagsByResource['${identifier.dnszones}']
  properties: {
    zoneType: 'Public'
  }
}
