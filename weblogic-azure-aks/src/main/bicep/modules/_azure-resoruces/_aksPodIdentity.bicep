/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param aksClusterName string = ''
param dbIdentity object = {}
param namespace string = 'sample-domain1-ns'
param podIdentityName string =''
param podIdentitySelector string = ''
param location string

var const_APIVersion = '2022-01-31-PREVIEW'

resource configAKSPodIdentity 'Microsoft.ContainerService/managedClusters@2022-09-02-preview' = {
  name: aksClusterName
  location: location
  properties: {
    podIdentityProfile:{
      allowNetworkPluginKubenet: false
      enabled: true
      userAssignedIdentities: [
        {
          bindingSelector: podIdentitySelector
          identity: {
            clientId: reference(items(dbIdentity.userAssignedIdentities)[0].key, const_APIVersion, 'full').properties.clientId
            objectId: reference(items(dbIdentity.userAssignedIdentities)[0].key, const_APIVersion, 'full').properties.principalId
            resourceId: items(dbIdentity.userAssignedIdentities)[0].key
          }
          name: podIdentityName
          namespace: namespace
        }
      ]
    }
  }
}
