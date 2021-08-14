{% include variables.md %}

# Add cache managed server to {{ site.data.var.wlsFullBrandName }} Coherence cluster

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} to add new managed cache server using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The `addnode-coherence.json` template will be applied to an existing {{ site.data.var.wlsFullBrandName }} **Coherence** cluster.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Coherence cluster

You can configure Coherence cluster from Azure portal or running Coherence sub template.

* Configure Coherence cluster from Azure portal

  Select `yes` in Coherence section and input required settings, the Azure WebLogic IaaS offer will configure a Coherence cluster automatically.

* Configure Coherence cluster via Coherence sub template

  Refer to [Configure Coherence cluster](coherenceTemplate.html).

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to `addnode-coherence.json` template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   You must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and nodes that to be added. This section shows how to obtain the values for the following required properties.

<table>
 <tr>
  <td>Parameter Name</td>
  <td colspan="2">Explanation</td>
 </tr>
 <tr>
  <td><code>_artifactsLocation</code></td>
  <td colspan="2">See below for details.</td>
 </tr>
 <tr>
  <td rowspan="7"><code>elkSettings</code></td>
  <td colspan="2">Optional. <a href="https://docs.microsoft.com/en-us/azure/architecture/building-blocks/extending-templates/objects-as-parameters">JSON object type</a>. You can specify this parameters for Elasticsearch and Kibana(ELK) connection. If <code>enable</code> is true, must specify other properties. See the page <a href="https://aka.ms/arm-oraclelinux-wls-elk">WebLogic with Elastic on Azure</a> for further information.</td>
 </tr>
 <tr>

  <td><code>enable</code></td>
  <td>If <code>enable</code> is true, must specify all properties of the <code>elkSettings</code>.</td>
 </tr>
 <tr>

  <td><code>elasticsearchEndpoint</code></td>
  <td>Endpoint of the Elasticsearch instance.</td>
 </tr>
 <tr>

  <td><code>elasticsearchPassword</code></td>
  <td>Password for Elasticsearch account.</td>
 </tr>
 <tr>

  <td><code>elasticsearchUserName</code></td>
  <td>User name for Elasticsearch account.</td>
 </tr>
 <tr>

  <td><code>logIndex</code></td>
  <td>Must be the same value output at ELK deployment time. </td>
 </tr>
 <tr>

  <td><code>logsToIntegrate</code></td>
  <td>Array with string value. Specify the expeted logs to integrate, you must input at least one log.</td>
 </tr>
 <tr>
  <td><code>adminPasswordOrKey</code></td>
  <td colspan="2">Password of administration account for the new Virtual Machine that host new nodes.</td>
 </tr>
 <tr>
  <td><code>adminVMName</code></td>
  <td colspan="2">Virtual machine name of which hosts the {{ site.data.var.wlsFullBrandName }} admin server, for example: <code>adminVM</code>.</td>
 </tr>
  <td><code>enableCoherenceWebLocalStorage</code></td>
  <td colspan="2">Specifies whether Local Storage is enabled for the Coherence*Web cluster tier.</td>
 </tr>
  <tr>
  <td><code>location</code></td>
  <td colspan="2">Must be the same region into which the server was initially deployed.</td>
 </tr>
 <tr>
  <td><code>managedServerPrefix</code></td>
  <td colspan="2">Must be the same prefix with which the cluster was initially deployed.</td>
 </tr>
 <tr>
  <td><code>numberOfExistingCacheNodes</code></td>
  <td colspan="2">Number of existing Coherence cache servers, used to name new virtual machines and new managed server.</td>
 </tr>
 <tr>
  <td><code>numberOfNewCacheNodes</code></td>
  <td colspan="2">Number of new Coherence cahce servers, used to create Virtual Machines and Managed Server.</td>
 </tr>
 <tr>
  <td><code>skuUrnVersion</code></td>
  <td colspan="2">Must be the same urn with which the cluster was initially deployed.</td>
 </tr>
 <tr>
  <td><code>storageAccountName</code></td>
  <td colspan="2">The name of an existing storage account.</td>
 </tr>
 <tr>
  <td><code>vmSizeSelectForCoherence</code></td>
  <td colspan="2">Select appropriate VM Size for Coherence cache servers.</td>
 </tr>
 <tr>
  <td><code>wlsDomainName</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
 <tr>
  <td><code>wlsPassword</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
 <tr>
  <td><code>wlsUserName</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
</table>

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateAddCacheNodeBasePath }}
```

### Existing cache nodes
To differentiate functionality of managed cache servers, we use **managed application server** to represent managed servers that host Java EE application, and use **managed cache server** to represent managed servers that used for cache.

You can get the existing managed cache servers with the following command:

```shell
$ resourceGroup=<your-resource-group>
$ managedServerPrefix=<managed-server-prefix>
$ numberOfExistingCacheNodes=$(az resource list -g ${resourceGroup} --resource-type Microsoft.Compute/virtualMachines --query [*].name | grep "${managedServerPrefix}StorageVM[0-9]" | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | sort  -nr | head -n1)
$ echo ${numberOfExistingCacheNodes}
```

### Log index

If you configured ELK in your cluster to export WebLogic Server logs to ELK, please input the value of Kibana log index, this template will set up ELK connection and export logs to specified index.

You can get the value from Azure portal with the following steps:

* Go to Azure portal.
* Open you resource group and click **Deployments**.
* Open the ELK deployment, and click **Output**.
* Copy the value of `logIndex`.

Alternatively, use Azure CLI command to list log index inside the resource group deployments:

```shell
$ az deployment group list -g 'yourResourceGroup' --query [*].properties.outputs.logIndex.value
[
  "azure-weblogic-cluster-f984df74-ab4d-4c17-a532-7f248659fb28"
]
```

### Storage account

Each Storage Account handles up to 20,000 IOPS, and 500TB of data. If you use a storage account for Standard Virtual Machines, you can store until 40 virtual disks.

We have two disks for one Virtual Machine, it's suggested no more than 20 Virtual Machines share the same storage account. Number of virtual machines that hosting managed servers should be less than or equal to 20.

You can get the name of storage account from Azure portal with steps:

  * Go to Azure portal
  * Go to the your resource group
  * Find storage account resource and copy its name

Alternatively, use Azure CLI command to list storage account inside a resource group:

```shell
$ az resource list -g 'yourResourceGroup' --resource-type Microsoft.Storage/storageAccounts --query [*].name
[
  "219846olvm"
]
```

#### Example Parameters JSON

Here is a fully filled out parameters file. We will leave values of `adminUsername`, `authenticationType`, `dnsLabelPrefix`,  `usePreviewImage` and `vmSizeSelectForCoherence` as default value. 

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateAddCacheNodeBasePath }}"
        },
        "adminPasswordOrKey": {
            "value": "jyfRat@nht2019"
        },
        "adminVMName": {
           "value": "adminVM"
        },
        "elkSettings": {
            "value": {
                "enable": true,
                "elasticsearchEndpoint":"https://example.eastus2.azure.elastic-cloud.com:9243",
                "elasticsearchPassword": "Secret123!",
                "elasticsearchUserName":"elastic",
                "logIndex": "azure-weblogic-dynamic-cluster-11122020",
                "logsToIntegrate": ["HTTPAccessLog", "ServerLog", "DomainLog", "DataSourceLog", "StandardErrorAndOutput", "NodeManagerLog"]
            }
        },
        "enableCoherenceWebLocalStorage": {
           "value": true
        },
        "location": {
            "value": "eastus"
        },
        "managedServerPrefix": {
           "value": "msp"
        },
        "numberOfExistingCacheNodes": {
            "value": 1
        },
        "numberOfNewCacheNodes": {
            "value": 1
        },
        "skuUrnVersion": {
          "value": "owls-122140-8u251-ol76;Oracle:weblogic-122140-jdk8u251-ol76:owls-122140-8u251-ol7;latest"
        },
        "storageAccountName": {
            "value": "d40140olvm"
        },
        "wlsDomainName": {
            "value": "wlsd"
        },
        "wlsPassword": {
          "value": "welcome1"
        },
        "wlsUserName": {
          "value": "weblogic"
        }
    }
}
```

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment to add new nodes.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az deployment group validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateAddCacheNodeBasePath }}arm/mainTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateAddCacheNodeBasePath }}arm/mainTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```bash
{
  "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Resources/deployments/mainTemplate",
  "location": null,
  "name": "mainTemplate",
  "properties": {
    "correlationId": "19040fc8-2b74-4e64-9dd9-59a5a3ce401a",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2/extensions/newuserscript",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM2/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Resources/deployments/pid-157ea8ac-12ae-11eb-adc1-0242ac120002",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "pid-157ea8ac-12ae-11eb-adc1-0242ac120002",
        "resourceType": "Microsoft.Resources/deployments"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/publicIPAddresses/mspStorageVM2_PublicIP",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM2_PublicIP",
            "resourceType": "Microsoft.Network/publicIPAddresses"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM2_NIC",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM2_NIC",
        "resourceType": "Microsoft.Network/networkInterfaces"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM2_NIC",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM2_NIC",
            "resourceType": "Microsoft.Network/networkInterfaces"
          },
          {
            "apiVersion": "2019-06-01",
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Storage/storageAccounts/33f2e3olvm",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "33f2e3olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM2",
        "resourceType": "Microsoft.Compute/virtualMachines"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM2",
            "resourceType": "Microsoft.Compute/virtualMachines"
          },
          {
            "actionName": "listKeys",
            "apiVersion": "2019-04-01",
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Storage/storageAccounts/33f2e3olvm",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "33f2e3olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM2/newuserscript",
        "resourceType": "Microsoft.Compute/virtualMachines/extensions"
      }
    ],
    "duration": "PT10M24.4018847S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM2/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM2_NIC",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/publicIPAddresses/mspStorageVM2_PublicIP",
        "resourceGroup": "haiche-cluster-1106"
      }
    ],
    "outputs": {
      "artifactsLocationPassedIn": {
        "type": "String",
        "value": "{{ armTemplateAddCacheNodeBasePath }}"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateAddCacheNodeBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminPasswordOrKey": {
        "type": "SecureString"
      },
      "adminUsername": {
        "type": "String",
        "value": "weblogic"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "authenticationType": {
        "type": "String",
        "value": "password"
      },
      "dnsLabelPrefix": {
        "type": "String",
        "value": "wls"
      },
      "enableCoherenceWebLocalStorage": {
        "type": "Bool",
        "value": true
      },
      "guidValue": {
        "type": "String",
        "value": "d5dde421-44b0-48df-9d12-db02374654d3"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "managedServerPrefix": {
        "type": "String",
        "value": "msp"
      },
      "numberOfExistingCacheNodes": {
        "type": "Int",
        "value": 1
      },
      "numberOfNewCacheNodes": {
        "type": "Int",
        "value": 1
      },
      "skuUrnVersion": {
        "type": "String",
        "value": "owls-122130-8u131-ol74;Oracle:weblogic-122130-jdk8u131-ol74:owls-122130-8u131-ol7;latest"
      },
      "storageAccountName": {
        "type": "String",
        "value": "33f2e3olvm"
      },
      "usePreviewImage": {
        "type": "Bool",
        "value": false
      },
      "vmSizeSelectForCoherence": {
        "type": "String",
        "value": "Standard_A1"
      },
      "wlsDomainName": {
        "type": "String",
        "value": "wlsd"
      },
      "wlsPassword": {
        "type": "SecureString"
      },
      "wlsUserName": {
        "type": "String",
        "value": "weblogic"
      }
    },
    "parametersLink": null,
    "providers": [
      {
        "id": null,
        "namespace": "Microsoft.Resources",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              null
            ],
            "properties": null,
            "resourceType": "deployments"
          }
        ]
      },
      {
        "id": null,
        "namespace": "Microsoft.Network",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "publicIPAddresses"
          },
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "networkInterfaces"
          }
        ]
      },
      {
        "id": null,
        "namespace": "Microsoft.Compute",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "virtualMachines"
          },
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "virtualMachines/extensions"
          }
        ]
      }
    ],
    "provisioningState": "Succeeded",
    "template": null,
    "templateHash": "16596437850900945013",
    "templateLink": null,
    "timestamp": "2020-11-09T06:28:40.936524+00:00"
  },
  "resourceGroup": "haiche-cluster-1106",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify

### Verify if new cache nodes are added to the WebLogic Server instance.

* Go to the {{ site.data.var.wlsFullBrandName }} Administration Console.
* Go to **Environment** -> **Machines**.

  You should see logical machines with name parttern `^{managedServerPrefix}StorageVM[0-9]+$`, machine names with number suffix from `numberOfExistingCacheNodes` to `numberOfExistingCacheNodes + numberOfNewCacheNodes` are added.
* Go to **Environment** -> **Servers**

  You should see servers with name parttern `^{managedServerPrefix}Storage[0-9]+$`, server names with number suffix from `numberOfExistingCacheNodes` to `numberOfExistingCacheNodes + numberOfNewNodes` are added to `storage1`.

### Verify if Azure resources are added

* Go to [Azure Portal](https://ms.portal.azure.com/).
* Go to resource group that the {{ site.data.var.wlsFullBrandName }} is deployed.

  You should see corresponding Vitual Machines, Disks, Network Interfaces, Public IPs have been added.
