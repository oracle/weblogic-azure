// Copyright (c) 2021, 2024 Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

param _globalResourceNameSufix string
param aksClusterRGName string = ''
param aksClusterName string = ''
param azCliVersion string = ''
param identity object = {}
param location string
@description('${label.tagsLabel}')
param tagsByResource object
param utcValue string = utcNow()
param wlsClusterName string = 'cluster-1'
param wlsDomainUID string = 'sample-domain1'

// To mitigate arm-ttk error: Unreferenced variable: $fxv#0
var base64_common = loadFileAsBase64('../../../arm/scripts/common.sh')
var base64_queryDomainConfigurations = loadFileAsBase64('../../../arm/scripts/inline-scripts/queryDomainConfigurations.sh')
var base64_utility = loadFileAsBase64('../../../arm/scripts/utility.sh')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@${azure.apiVersionForDeploymentScript}' = {
  name: 'ds-query-wls-configurations-${_globalResourceNameSufix}'
  location: location
  kind: 'AzureCLI'
  identity: identity
  tags: tagsByResource['${identifier.deploymentScripts}']
  properties: {
    azCliVersion: azCliVersion
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
    scriptContent: format('{0}\r\n\r\n{1}\r\n\r\n{2}',base64ToString(base64_common), base64ToString(base64_utility), base64ToString(base64_queryDomainConfigurations))
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    forceUpdateTag: utcValue
  }
}

output shellCmdtoOutputWlsDomainYaml string = format('echo -e {0} | base64 -d > domain.yaml', deploymentScript.properties.outputs.domainDeploymentYaml)
output shellCmdtoOutputWlsImageModelYaml string = format('echo -e {0} | base64 -d > model.yaml', deploymentScript.properties.outputs.wlsImageModelYaml)
output shellCmdtoOutputWlsImageProperties string = format('echo -e {0} | base64 -d > model.properties', deploymentScript.properties.outputs.wlsImageProperties)
output shellCmdtoOutputWlsVersions string = format('echo -e {0} | base64 -d > version.info', deploymentScript.properties.outputs.wlsVersionDetails)
