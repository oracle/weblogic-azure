{% include variables.md %}

# Delete nodes from {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} to delete nodes using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the delete-node ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   You must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and nodes to be deleted. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `adminVMName`| At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `deletingManagedServerNames` | The names of managed server that you want to delete. |
| `deletingManagedServerMachineNames`| The resource names of Azure Virtual Machine hosting managed servers that you want to delete. |
| `wlsPassword` | Must be the same value provided at deployment time. |
| `wlsUserName` | Must be the same value provided at deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateDeleteNodeBasePath }}
```

### `deletingManagedServerNames`

This value must be an array of strings, for example: `["msp1", "msp2"]`.

You can get the server names from WebLogic Server Administration Console, following the steps:

* Go to WebLogic Server Administration Console, http://admin-host:7001/console.

* Go to  **Environment** -> **Servers**. 

  You will find all available servers. Server names are listed in **Name** column. 

  Make note of the machine for the deleting servers, you need to find out corresponding Azure Virtual Machine names of those machines.

### `deletingManagedServerMachineNames`

This value must be an array of strings, for example: `["mspVM1", "mspVM2"]`.

You can get the server names from WebLogic Server Administration Console, following the steps:

* Go to WebLogic Server Administration Console, http://admin-host:7001/console.

* Go to **Environment** -> **Machines**.

  Open the machine you noted down in step `deletingManagedServerNames`.

  Click **Configuration** -> **Node Manager**, you will get compute name from **Listen Address**. 

 The Azure Virtual Machine name was set with the same value of compute name during {{ site.data.var.wlsFullBrandName }} deployment.

#### Example Parameters JSON

Here is a fully filled out parameters file.   Note that here we do not include `adminVMName`.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateDeleteNodeBasePath }}"
        },
        "deletingManagedServerNames": {
            "value": [
                "msp4",
                "mspStorage2"
            ]
        },
        "deletingManagedServerMachineNames": {
            "value": [
                "mspVM4",
                "mspStorageVM2"
            ]
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

## Invoke the delete-node script

To delete managed nodes completely, you have to delete managed servers logically from the WebLogic Server instance, and physically release Azure resources that host the managed servers.  We realize the two purposes in different ways:
  * Delete managed servers and machines logically from WebLogic Server instance by deploying delete-node ARM template with Azure CLI. You have to specify the parameters file.
  * Release corresponding Azure resources by running Azure CLI commands. The following resources will be removed:
    * Virtual Machines that host managed servers that will be deleted.
    * Data disks attached to the Virtual Machines
    * OS disks attached to the Virtual Machines
    * Network Interfaces added to the Virtual Machines
    * Public IPs attached to the Virtual Machines
    * If the Application Gateway is deployed, will remove the manged server hosts from gateway.

We have provided an automation script for above two purposes, you can delete managed nodes easily with the following instructions.

### Invoke the script

Assume your parameters file is available in the current directory and is named `parameters.json`.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

The following command runs the script in silent mode with option `-s`, this mode will delete managed nodes logically and physically.

If you want to keep Azure resources, refer to [advanced usage](#advanced-usage) for further information.

```bash
$ curl -fsSL {{ armTemplateDeleteNodeBasePath }}scripts/deletenode-cli.sh | /bin/bash -s -- -s -g `yourResourceGroup` -u {{ armTemplateDeleteNodeBasePath }}arm/mainTemplate.json -p parameters.json
```

The script will validate the template with your parameters file; deploy the template to delete managed servers from WebLogic Server cluster; run Azure CLI commands to delete corresponding Azure resources.

This is an example output of successful deployment, the  {{ site.data.var.wlsFullBrandName }} is deployed with Application Gateway.  Look for `Completed!` in your output.

```bash
{
  "error": null,
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/mainTemplate",
  "name": "mainTemplate",
  "properties": {
    "correlationId": "cbfaa443-3a72-4217-83e1-cc91485597fa",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-cluster-07232",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceGroup": "oraclevm-cluster-07232",
        "resourceName": "pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT0S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputs": null,
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateDeleteNodeBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "deletingManagedServerMachineNames": {
        "type": "Array",
        "value": [
          "mspVM2"
        ]
      },
      "deletingManagedServerNames": {
        "type": "Array",
        "value": [
          "msp2"
        ]
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "wlsForceShutDown": {
        "type": "String",
        "value": "true"
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
    "templateHash": "3171958496378517565",
    "templateLink": {
      "contentVersion": "1.0.0.0",
      "uri": "{{ armTemplateDeleteNodeBasePath }}arm/mainTemplate.json"
    },
    "timestamp": "2020-07-23T07:44:38.977624+00:00",
    "validatedResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-7d4ae6d6-17c5-5168-b7d2-e0bf33a1e878",
        "resourceGroup": "oraclevm-cluster-07232"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-cluster-07232"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceGroup": "oraclevm-cluster-07232"
      }
    ]
  },
  "resourceGroup": "oraclevm-cluster-07232",
  "type": "Microsoft.Resources/deployments"
}
Accepted: newuserscript (Microsoft.Compute/virtualMachines/extensions)
Accepted: deletenode-1595490274 (Microsoft.Resources/deployments)
Command ran in 102.719 seconds (init: 0.061, invoke: 102.658)
Extension 'resource-graph' is already installed.
List resource Ids to be deleted: 
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/mspVM2
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/networkInterfaces/mspVM2_NIC
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/publicIPAddresses/mspVM2_PublicIP
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/ORACLEVM-CLUSTER-07232/providers/Microsoft.Compute/disks/mspVM2_OsDisk_1_e6d8ffb0e73649a4a713acf5e6ca7099
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/ORACLEVM-CLUSTER-07232/providers/Microsoft.Compute/disks/mspVM2_lun_0_2_942609646fdc4e1dab06b23ffeee650f
Are you sure to delete these resources (y/n)?Deleting managed resources...Please do not stop.
[
  null,
  null,
  null,
  null,
  null
]
Command ran in 112.375 seconds (init: 0.062, invoke: 112.313)
Check if application gateway has deployed...
Removing mspVM2 from application gateway, please do not stop.
{
  "backendAddresses": [
    {
      "fqdn": "mspVM1",
      "ipAddress": null
    },
    {
      "fqdn": "mspVM3",
      "ipAddress": null
    }
  ],
  "backendIpConfigurations": null,
  "etag": "W/\"23399346-e17b-4f56-bda4-5e77c1d82195\"",
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/applicationGateways/myAppGateway/backendAddressPools/myGatewayBackendPool",
  "name": "myGatewayBackendPool",
  "provisioningState": "Succeeded",
  "resourceGroup": "oraclevm-cluster-07232",
  "type": "Microsoft.Network/applicationGateways/backendAddressPools"
}

Complete!
```

### Advanced usage

If you want to learn more about the script and run it manually, follow the advanced instructions to interact with the ternimal.

  * Download the script

  ```bash
  $ curl -fsSL {{ armTemplateDeleteNodeBasePath }}scripts/deletenode-cli.sh
  ```

  You will get a shell script named `deletenode-cli.sh` in your current directory. Usage of the script:

  ```bash
  ./deletenode-cli.sh -h
  usage: deletenode-cli.sh -g resource-group [-f template-file] [-u template-url] -p paramter-file [-h]
  -g Azure Resource Group of the Vitural Machines that host deleting manages servers, must be specified.
  -f Path of ARM template to delete nodes, must be specified -f option or -u option.
  -u URL of ARM template, must be specified -f option or -u option.
  -p Path of ARM parameter, must be specified.
  -s Execute the script in silent mode. The script will input y automatically for the prompt.
  -h Help
  ```

  You can not only run the script with a local template file by specifying `-f` option, but also with a templatle URL using `-u` option.

  * Run the script

  Run the script with your parameters file in your current directory. The following command runs with a template URL:

  ```bash 
  ./deletenode-cli.sh -g yourResourceGroup -u {{ armTemplateDeleteNodeBasePath }}arm/mainTemplate.json -p parameters.json
  ```

  Before deleting any Azure resource, the script will prompt up message **Are you sure to delete these resources (y/n)?** to comfirm if you want to delete Azure resources. If you input `Y/y`, the Azure resources will be deleted. Otherwise, keep the resource and exit.

  This is an example output of deployment that will not delete Azure resources from your resource group, the  {{ site.data.var.wlsFullBrandName }} is deployed with Application Gateway.  Look for `Completed!` in your output.

  ```bash
  {
  "error": null,
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/mainTemplate",
  "name": "mainTemplate",
  "properties": {
    "correlationId": "4b15b45b-fb1f-4def-ad32-d96201000ac1",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-cluster-07232",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceGroup": "oraclevm-cluster-07232",
        "resourceName": "pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT0S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputs": null,
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateDeleteNodeBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "deletingManagedServerMachineNames": {
        "type": "Array",
        "value": [
          "mspVM3"
        ]
      },
      "deletingManagedServerNames": {
        "type": "Array",
        "value": [
          "msp3"
        ]
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "wlsForceShutDown": {
        "type": "String",
        "value": "true"
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
    "templateHash": "3171958496378517565",
    "templateLink": {
      "contentVersion": "1.0.0.0",
      "uri": "{{ armTemplateDeleteNodeBasePath }}arm/mainTemplate.json"
    },
    "timestamp": "2020-07-24T04:17:38.500948+00:00",
    "validatedResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-7d4ae6d6-17c5-5168-b7d2-e0bf33a1e878",
        "resourceGroup": "oraclevm-cluster-07232"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-cluster-07232"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Resources/deployments/pid-4b263220-3cc6-53b9-aef3-23ad10c45d52",
        "resourceGroup": "oraclevm-cluster-07232"
      }
    ]
  },
  "resourceGroup": "oraclevm-cluster-07232",
  "type": "Microsoft.Resources/deployments"
}
Succeeded: pid-7d4ae6d6-17c5-5168-b7d2-e0bf33a1e878 (Microsoft.Resources/deployments)
Accepted: deletenode-1595564252 (Microsoft.Resources/deployments)
Accepted: newuserscript (Microsoft.Compute/virtualMachines/extensions)
Command ran in 102.182 seconds (init: 0.089, invoke: 102.092)
Extension 'resource-graph' is already installed.
List resource Ids to be deleted: 
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Compute/virtualMachines/mspVM3
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/networkInterfaces/mspVM3_NIC
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/publicIPAddresses/mspVM3_PublicIP
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/ORACLEVM-CLUSTER-07232/providers/Microsoft.Compute/disks/mspVM3_OsDisk_1_d5e69682dbff491e97b7a04eea3896eb
/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/ORACLEVM-CLUSTER-07232/providers/Microsoft.Compute/disks/mspVM3_lun_0_2_f5bfbf93870f4ed3b1d90a8b953818e7
Are you sure to delete these resources (y/n)?n
Check if application gateway has deployed...
Removing mspVM3 from application gateway, please do not stop.
{
  "backendAddresses": [
    {
      "fqdn": "mspVM1",
      "ipAddress": null
    }
  ],
  "backendIpConfigurations": null,
  "etag": "W/\"b6f76f57-be98-406d-ac9c-d11035fd3b5b\"",
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-07232/providers/Microsoft.Network/applicationGateways/myAppGateway/backendAddressPools/myGatewayBackendPool",
  "name": "myGatewayBackendPool",
  "provisioningState": "Succeeded",
  "resourceGroup": "oraclevm-cluster-07232",
  "type": "Microsoft.Network/applicationGateways/backendAddressPools"
}

Complete!
  ```

## Verify

### Verify if the managed servers are deleted from WebLogic Server instance.

* Go to the {{ site.data.var.wlsFullBrandName }} Administration Console.
* Go to  **Environment** -> **Servers**.
  You should see no server names that have been deleted listed in **Name** column.
* Go to **Environment -> Machines**.
  You should see logical machines that host the servers that have been deleted are removed.

### Verify if the Azure resources are deleted

* Go to [Azure Portal](https://ms.portal.azure.com/).
* Go to resource group that the {{ site.data.var.wlsFullBrandName }} is deployed.
  You should see corresponding Vitual Machines, Disks, Network Interfaces, Public IPs have been removed.

  For example, I want to delete managed server `msp1`, corresponding Virtual Machine name is `mspVM1`, Azure resource names are:
    * Virtual Machine: `mspVM1`
    * Data Disk: `mspVM1_lun_0_2_9d41e2c965744665adb6965625c20d9a`
    * OS Disk: `mspVM1_OsDisk_1_05a8d81f5d01419a97ee17a45f974dca`
    * Network Interface: `mspVM1_NIC`
    * Public IP: `mspVM1_PublicIP`

  All of these resource should be deleted after the script finishes, unless you don't expect to delete them without specifying "Y/y" to the prompt.