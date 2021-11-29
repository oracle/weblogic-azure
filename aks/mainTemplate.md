<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Create Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration

This page documents how to create Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration using Azure CLI.

## Introduction

We have [Azure Marketplace offer](https://portal.azure.com/?feature.customPortal=false#create/oracle.20210620-wls-on-aks20210620-wls-on-aks) that 
makes it easy to get started with WebLogic Server on Azure, see [document](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/). 
If you want the following advanced usage, we have mainTemplate which enables you to customize your WebLogic cluster.

- Customize Azure Container Insight with specified retension days, workaspace SKU and resource permissions.

- Customize Azure Kubernetes Service version and Agent Pool name.

- Create custom T3 channel for WebLogic Administration Server and cluster and expose the T3 channel via Azure Standard Load Balancer serive.

- Customize the CPU and memory resource for server pod, which default by 200m and 1.5Gi.

The mainTemplate enables you not only to create a new WebLogic cluster, but also to refresh your existing cluster with new inputs.

This document will guide you to create a new WebLogic cluster using the advanced configurations.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### Azure Managed Indentify

You are required to input the ID of a user-assigned managed identity. 

Follow this [guide](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal) 
to create a user-assigned managed identity.

To obtain ID of the indentify: go to Azure Portal; open the identity **Overview** page; click **JSON View** and copy the **Resource ID**.

### Azure Service Principal

Optional.

You are required to input a Base64 encoded JSON string of a service principal for the selected subscription 
if you are going to enable Azure Application Gatway ingress. 

You can generate one with command `az ad sp create-for-rbac --sdk-auth | base64 -w0`.

### Database Instance

Optional.

If you are going to apply a database with {{ site.data.var.wlsFullBrandName }},
you must have an existing database instance to use.  This template
supports three popular Azure databases: [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), 
[Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/) and [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal).  If you do not have an instance, please
create one from the Azure portal. If you want to use other databse, you must provide a running data server, 
make sure the database is accessible from Azure, you can contact [Azure Java EE team](https://aka.ms/wls-aks-contactme) for support, 
see [Database](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/#database) for configuration.

### Custom DNS

Optional.

{% include sub-template-dnszone.md %}

## Prepare the Parameters

You must construct a parameters JSON file containing the parameters to the database ARM template.
See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.
This section shows how to obtain the values for the required properties.

### Obtain parameter values from Azure portal

The first step is to obtain the parameter values from Azure portal, as Azure portal eases the interface and validation. 
You can also create the objects in your parameter file directly.

The following steps are leveraging [Azure Create UI Definition Sandbox](https://portal.azure.com/?feature.customPortal=false#blade/Microsoft_Azure_CreateUIDef/SandboxBlade) to obtain the value of parameters that are available from Azure portal. The Azure UI Definition Sandbox provides controls to select resources and input your value easily. 

- Use your favourite browser and open [Azure UI Definition Sandbox](https://portal.azure.com/?feature.customPortal=false#blade/Microsoft_Azure_CreateUIDef/SandboxBlade).

- Clear the content of Azure UI Definition Sandbox, and replace with the content of [createUiDefinition.json]({{ armTemplateBasePath }}createUiDefinition.json)

- Click **Preview**

- Fill in values, see [running Oracle WebLogic Server on Azure Kuberneters Service document](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/).

- Click **Review+create**, after you finish the inputs. The Azure UI Definition Sandbox will validate the inputs, you must resolve error if there is before going on. 

  You will find a message "Validation Passed".

- Click "View outputs payload", copy the payload and save it to a file named `parameters.json`

### Configure advanced parameters

| Advanced parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| Required. See below for details. |
| `aciResourcePermissions`| Optinal. The parameter activates when Azure Container Insight is enabled, `enableAzureMonitoring=true`. `false`: Set the workspace to workspace-context permissions. This is the default setting if the flag isn't set. `true`: Set the workspace to resource-context permissions. See [Azure Monitor access control mode](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/manage-access#configure-access-control-mode) |
| `aciRetentionInDays`| Optinal. Number of days to retain data in Azure Monitor workspace. |
| `aciWorkspaceSku`| Optinal. Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.. |
| `aksAgentPoolName` | Optinal. The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters. |
| `aksVersion`| Optinal. Version of Azure Kubernetes Service. Use default version if no specified value. |
| `enableAdminT3Tunneling`| Optinal. Configure a custom channel in Admin Server for the T3 protocol that enables HTTP tunneling. |
| `enableClusterT3Tunneling` | Optinal. Configure a custom channel in WebLogic cluster for the T3 protocol that enables HTTP tunneling. |
| `t3ChannelAdminPort` | Optinal. Sepcify cublic port of the custom T3 channel in admin server. |
| `t3ChannelClusterPort` | Optinal. Specify public port of the custom T3 channel in WebLoigc cluster. |
| `wlsCPU` | Optinal. Sepcify CPU requests for admin server and managed server pods. |
| `wlsMemory` | Optinal. Specify memory requests for admin server and managed server pods. |


#### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

Append the expected advanced parameter to `parameters.json`. And make sure `_artifactsLocation` is presenting in `parameters.json`.

#### Example Parameters JSON

This is a sample to create WebLogic cluster with custom T3 channel, and expose the T3 channel via Azure Load Balancer Service. 
The parameters using default value haven't been shown for brevity.

```json
{
    "_artifactsLocation": {
        "value": "{{ armTemplateBasePath }}"
    },
    "createACR": {
      "value": true
    },
    "enableAdminT3Tunneling": {
      "value": true
    },
    "enableClusterT3Tunneling": {
      "value": true
    },
    "identity": {
      "value": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/subscription-id/resourceGroups/samples/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azure_wls_aks": {}
        }
      }
    },
    "lbSvcValues": {
      "value": [
        {
          "colName": "domain1-admin-t3",
          "colTarget": "adminServerT3",
          "colPort": "7005"
        },
        {
          "colName": "domain-cluster-t3",
          "colTarget": "cluster1T3",
          "colPort": "8011"
        }
      ]
    },
    "location": {
      "value": "eastus"
    },
    "ocrSSOPSW": {
      "value": "Secret123!"
    },
    "ocrSSOUser": {
      "value": "sample@foo.com"
    },
    "wdtRuntimePassword": {
      "value": "Secret123!"
    },
    "wlsPassword": {
      "value": "Secret123!"
    },
    "wlsUserName": {
      "value": "weblogic"
    }
  }
```

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`. 
This section shows the commands to create WebLogic cluster on AKS.

Use the command to create a resoruce group.

```shell
resourceGroupName="hello-wls-aks"
az group create --name ${resourceGroupName} -l eastus
```

### Validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose \
  --resource-group ${resourceGroupName} \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}mainTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose \
  --resource-group ${resourceGroupName} \
  --name advanced-deployment \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}mainTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

After a successful deployment, you should find `"provisioningState": "Succeeded"` in your output.


## Verify deployment

The sample has set up custom T3 channel for Administration Server and cluster, you should be able to access Administration Console portal 
using the public address of T3 channel.

Obtain the address from deployment output:

  - Open your resource group from Azure portal.
  - Click **Settings** -> **Deployments** -> the deployment with name `advanced-deployment`, listed in the bottom.
  - Click **Outputs** of the deployment, copy the value of `adminServerT3ExternalUrl`

Access `${adminServerT3ExternalUrl}/console` from browser, you should find the login page.

 