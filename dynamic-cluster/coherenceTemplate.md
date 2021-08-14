{% include variables.md %}

# Configure Coherence cluster to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with a Coherence cluster using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The Coherence ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

**Note:** if you have enabled Coherence in the initial offer deployment from Azure portal, the Coherence cluster has been set up, you don't need to run Coherence tempalte.

### Elasticsearch instance

Optional.

Refer to [Create an an Elastic on Azure instance](https://aka.ms/arm-oraclelinux-wls-elk#create-an-an-elastic-on-azure-instance)

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the Coherence ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.

The deployment of coherenceTemplate.json will:
  * Provision Azure resources, including virtual machine, network interface, disk, public IP to host new Coherence cache servers.
  * Configure WebLogic Coherence cluster, including:
    * Create Coherence cluster `myCoherence`
    * Create data tier `storage1` cluster.
    * Associate  `cluster1` and `storage1` to `myCoherence` cluster.
    * Create cache servers and assign them to `storage1` cluster. 

We must specify the information of the existing {{ site.data.var.wlsFullBrandName }}. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `adminPasswordOrKey` | SSH Key or password for the Virtual Machine. SSH key is recommended. | 
| `adminVMName`| Virtual machine name of which hosts the {{ site.data.var.wlsFullBrandName }} admin server. |
| `elasticsearchEndpoint` | The Elasticsearch endpoint. |
| `elasticsearchPassword` | Password for the Elasticsearch account. |
| `elasticsearchUserName` | User name for the Elasticsearch account. |
| `enableCoherenceWebLocalStorage` | Specifies whether Local Storage is enabled for the Coherence*Web cluster tier. |
| `enableELK` | If true, use the supplied parameters to distribute WebLogic Server logs to the Elasticsearch instance. |
| `location` | Must be the same region into which the server was initially deployed. |
| `logIndex` | Elasticsearch index you expect to export the logs to. Must be the same value with output from initial ELK deployment. |
| `logsToIntegrate` | Specify the WebLogic logs to export to Elasticsearch, you must select at least one log. |
| `managedServerPrefix` | Must be the same prefix with which the cluster was initially deployed. |
| `numberOfCoherenceCacheInstances` | Number of Coherence cache servers, used to create Virtual Machines and Managed Server. |
| `skuUrnVersion` | Must be the same urn with which the cluster was initially deployed. |
| `storageAccountName` | The name of an existing storage account. |
| `vmSizeSelectForCoherence` | Select appropriate VM Size for Coherence cache servers. |
| `wlsDomainName` | Must be the same value provided at initial deployment time. |
| `wlsPassword` | Must be the same value provided at initial deployment time. |
| `wlsUserName` | Must be the same value provided at initial deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
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

Here is a fully filled out parameters file.  This is an example to set up Coherence*Web.  We will leave values of `adminUsername`, `authenticationType`, `dnsLabelPrefix`,  and `usePreviewImage` as default value. 

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateBasePath }}"
        },
        "adminPasswordOrKey": {
            "value": "jyfRat@nht2019"
        },
        "adminVMName": {
           "value": "adminVM"
        },
        "elasticsearchEndpoint": {
           "value": "https://example.eastus2.azure.elastic-cloud.com:9243"
        },
        "elasticsearchPassword": {
           "value": "Secret123!"
        },
        "elasticsearchUserName": {
           "value": "elastic"
        },
        "enableCoherenceWebLocalStorage": {
           "value": true
        },
        "enableELK": {
          "value": true
        },
        "managedServerPrefix": {
           "value": "msp"
        },
        "location": {
            "value": "eastus"
        },
        "logIndex": {
            "value": "azure-weblogic-cluster-11122020"
        },
        "logsToIntegrate": {
          "value": ["HTTPAccessLog", "ServerLog", "DomainLog", "DataSourceLog", "StandardErrorAndOutput","NodeManagerLog"]
        },
        "numberOfCoherenceCacheInstances": {
            "value": 1
        },
        "skuUrnVersion": {
          "value": "owls-122140-8u251-ol76;Oracle:weblogic-122140-jdk8u251-ol76:owls-122140-8u251-ol7;latest"
        },
        "storageAccountName": {
            "value": "d40140olvm"
        },
        "vmSizeSelectForCoherence": {
            "value": "Standard_A1"
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

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with a Coherence cluster.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az deployment group validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/coherenceTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/coherenceTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```json
{
  "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Resources/deployments/coherenceTemplate",
  "location": null,
  "name": "coherenceTemplate",
  "properties": {
    "correlationId": "07555c54-2384-4ca3-b427-6cf7d8b53052",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          },
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1/extensions/newuserscript",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM1/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Resources/deployments/pid-157eaa6e-12ae-11eb-adc1-0242ac120002",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "pid-157eaa6e-12ae-11eb-adc1-0242ac120002",
        "resourceType": "Microsoft.Resources/deployments"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/publicIPAddresses/mspStorageVM1_PublicIP",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM1_PublicIP",
            "resourceType": "Microsoft.Network/publicIPAddresses"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM1_NIC",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM1_NIC",
        "resourceType": "Microsoft.Network/networkInterfaces"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM1_NIC",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM1_NIC",
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
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM1",
        "resourceType": "Microsoft.Compute/virtualMachines"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM1",
            "resourceType": "Microsoft.Compute/virtualMachines"
          },
          {
            "actionName": "listKeys",
            "apiVersion": "2019-06-01",
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Storage/storageAccounts/33f2e3olvm",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "33f2e3olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "adminVM/newuserscript",
        "resourceType": "Microsoft.Compute/virtualMachines/extensions"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "mspStorageVM1",
            "resourceType": "Microsoft.Compute/virtualMachines"
          },
          {
            "actionName": "listKeys",
            "apiVersion": "2019-06-01",
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Storage/storageAccounts/33f2e3olvm",
            "resourceGroup": "haiche-cluster-1106",
            "resourceName": "33f2e3olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106",
        "resourceName": "mspStorageVM1/newuserscript",
        "resourceType": "Microsoft.Compute/virtualMachines/extensions"
      }
    ],
    "duration": "PT9M26.6278882S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Compute/virtualMachines/mspStorageVM1/extensions/newuserscript",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/networkInterfaces/mspStorageVM1_NIC",
        "resourceGroup": "haiche-cluster-1106"
      },
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-cluster-1106/providers/Microsoft.Network/publicIPAddresses/mspStorageVM1_PublicIP",
        "resourceGroup": "haiche-cluster-1106"
      }
    ],
    "outputs": {
      "artifactsLocationPassedIn": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "_artifactsLocationCoherenceTemplate": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
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
        "value": "b4c17707-b932-43f0-a4cc-6d6990bb850f"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "managedServerPrefix": {
        "type": "String",
        "value": "msp"
      },
      "numberOfCoherenceCacheInstances": {
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
    "templateHash": "7840329080326569798",
    "templateLink": null,
    "timestamp": "2020-11-06T08:48:57.229200+00:00"
  },
  "resourceGroup": "haiche-cluster-1106",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify Coherence cluster

Follow the steps to check if Coherence*Web is enabled.

* Follow the example parameters to set up Coherence*Web.
* Go to admin console portal.
* Deploy [coherence-sample.war](../resources/coherence-sample.war) to `cluster1`.
    Please select `cluster1` in the Targets page.
* Start `coherence-sample`.
* Open the sample with browser, click "add session" to add session infomation. Click "test session" to verify.

If the Coherence cluster does not set up successfully, the application deployment will fail.

If the cache server does not work correctly, session can not be saved, as we disabled local storage in application servers.
