{% include variables.md %}

# Land {{ site.data.var.wlsFullBrandName }} logs to Elasticsearch and Kibana

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} to land logs to Elasticsearch and Kibana using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The ELK ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Virtual machine size requirement
Ensure the virtual machines that have been deployed have at least **2.5GB** of memory. The default virtual machine size for WLS does not have enough memory. Use at least `Standard_A2_v2`.

### Elasticsearch instance

Refer to [Create an an Elastic on Azure instance](https://aka.ms/arm-oraclelinux-wls-elk#create-an-an-elastic-on-azure-instance)

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the ELK ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files. 

We must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and Elasticsearch instance. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `adminVMName`| Virtual machine name of which hosts the {{ site.data.var.wlsFullBrandName }} admin server. |
| `elasticsearchEndpoint` | The Elasticsearch endpoint. |
| `elasticsearchPassword` | Password of the Elasticsearch account. Used to distibute message with REST API to Elasticsearch instance. |
| `elasticsearchUserName` | User name of the Elasticsearch account. |
| `location` | Must be the same region into which the server was initially deployed. |
| `logsToIntegrate` | Specify the WebLogic logs to export to Elasticsearch, you must select at least one log. |
| `wlsDomainName` | Must be the same value provided at initial deployment time. |
| `wlsPassword` | Must be the same value provided at initial deployment time. |
| `wlsUserName` | Must be the same value provided at initial deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

#### Example Parameters JSON

Here is a fully filled out parameters file.  We will leave values of `adminUsername`, `authenticationType`, `dnsLabelPrefix`,  and `usePreviewImage` as default value. 

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateBasePath }}"
        },
        "adminVMName": {
           "value": "adminVM"
        },
        "elasticsearchEndpoint": {
           "value": "https://example.eastus2.azure.elastic-cloud.com:9243"
        },
        "elasticsearchPassword": {
           "value": "wlkpsw"
        },
        "elasticsearchUserName": {
           "value": "elastic"
        },
        "location": {
            "value": "eastus"
        },
        "wlsDomainName": {
            "value": "adminDomain"
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

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment to connect to Elasticsearch and Kinaba intance.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/elkNestedTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/elkNestedTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```json
{
  "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-admin-elk/providers/Microsoft.Resources/deployments/elkNestedTemplate",
  "location": null,
  "name": "elkNestedTemplate",
  "properties": {
    "correlationId": "61a46b43-27d0-4478-baba-c288059892d5",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-admin-elk/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "haiche-admin-elk",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-admin-elk/providers/Microsoft.Resources/deployments/pid-e4165284-b017-5df9-9b91-3f11dd8a72e5",
        "resourceGroup": "haiche-admin-elk",
        "resourceName": "pid-e4165284-b017-5df9-9b91-3f11dd8a72e5",
        "resourceType": "Microsoft.Resources/deployments"
      },
    ],
    "duration": "PT8M54.4785762S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/685ba005-af8d-4b04-8f16-a7bf38b2eb5a/resourceGroups/haiche-admin-elk/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "haiche-admin-elk"
      }
    ],
    "outputs": {
      "artifactsLocationPassedIn": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "logIndex": {
        "type": "String",
        "value": "azure-weblogic-admin-b4e465d5-6ffc-49cf-b1d9-b4dbf6455d0a"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "_artifactsLocationELKTemplate": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "elasticsearchEndpoint": {
        "type": "String",
        "value": "https://example.eastus2.azure.elastic-cloud.com:9243"
      },
      "elasticsearchPassword": {
        "type": "SecureString"
      },
      "elasticsearchUserName": {
        "type": "String",
        "value": "elastic"
      },
      "guidValue": {
        "type": "String",
        "value": "b4e465d5-6ffc-49cf-b1d9-b4dbf6455d0a"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "logsToIntegrate": {
        "type": "Array",
        "value": [
          "HTTPAccessLog",
          "ServerLog",
          "DomainLog",
          "DataSourceLog",
          "StandardErrorAndOutput",
          "NodeManagerLog"
        ]
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
            "resourceType": "virtualMachines/extensions"
          }
        ]
      }
    ],
    "provisioningState": "Succeeded",
    "template": null,
    "templateHash": "10060935779116645392",
    "templateLink": null,
    "timestamp": "2020-11-11T07:29:42.336797+00:00"
  },
  "resourceGroup": "haiche-admin-elk",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify ELK connection

Follow the steps to check if WebLogic Server logs are exported to Elasticsearch.

* Go to Azure portal
* Copy log index from your resource group -> deployments -> elkNestedTemplate -> output -> logIndex .
* Go to Elasticsearch cloud and launch Kibana.
* Create index
  * Go to Kibana -> Management -> Kibana -> Index Patterns
  * Click `Create index Patterns`
  * Input the log index you copy from output in Index pattern
  * There should be an index you can select, otherwise, the ELK deployment failed
  * Next step
  * Select `@timestamp` in Time Filter and hit `Create index pattern`
* View logs
  * Go to Kibana -> Discover
  * Select the index you just created
  * You will find the WebLogic Server logs listed
