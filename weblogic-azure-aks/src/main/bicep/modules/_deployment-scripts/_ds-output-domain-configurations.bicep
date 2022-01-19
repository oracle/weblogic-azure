// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param aksClusterRGName string = ''
param aksClusterName string = ''
param identity object
param location string
param utcValue string = utcNow()
param wlsClusterName string = 'cluster-1'
param wlsDomainUID string = 'sample-domain1'

var const_azcliVersion='2.15.0'
var const_deploymentName='ds-query-wls-configurations'

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-query-wls-configurations'
  location: location
  kind: 'AzureCLI'
  identity: identity
  properties: {
    azCliVersion: const_azcliVersion
    environmentVariables: [
      {
        name: 'AKS_CLUSTER_RESOURCEGROUP_NAME'
        value: aksClusterRGName
      }
      {
        name: 'AKS_CLUSTER_NAME'
        value: aksClusterName
      }
      {
        name: 'WLS_CLUSTER_NAME'
        value: wlsClusterName
      }
      {
        name: 'WLS_DOMAIN_UID'
        value: wlsDomainUID
      }
    ]
    scriptContent: loadTextContent('../../../arm/scripts/inline-scripts/queryDomainConfigurations.sh')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output shellCmdtoOutputWlsDomainYaml string = format('echo -e {0} | base64 -d > domain.yaml', reference(const_deploymentName).outputs.domainDeploymentYaml)
output shellCmdtoOutputWlsImageModelYaml string = format('echo -e {0} | base64 -d > model.yaml', reference(const_deploymentName).outputs.wlsImageModelYaml)
output shellCmdtoOutputWlsImageProperties string = format('echo -e {0} | base64 -d > model.properties', reference(const_deploymentName).outputs.wlsImageProperties)
output shellCmdtoOutputWlsVersions string = format('echo -e {0} | base64 -d > version.info', reference(const_deploymentName).outputs.wlsVersionDetails)
