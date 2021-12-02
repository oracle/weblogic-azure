<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Update Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration

This page documents how to update Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration using Azure CLI.

## Introduction

{% include sub-template-advanced-usage.md %}

This document will guide you to update a WebLogic cluster using the advanced configurations.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The database ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Azure Managed Indentify

You are required to input the ID of a user-assigned managed identity. 

Follow this [guide](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal) 
to create a user-assigned managed identity.

To obtain ID of the indentify: go to Azure Portal; open the identity **Overview** page; click **JSON View** and copy the **Resource ID**.

### Azure Storage account 

If you are deploying Java EE application or using your own datasource driver, you are required to 
have application packages and jdbc libraries in Azure Storage Account.

Follow this [guide](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) to create Azure Storage Account and blobs.

Upload your application packages (.jar, .war, .ear files) to the blob.

Upload your jdbc drivers (.jar files) to the blob.

### Azure Service Principal

Optional.

If you are going to enable Azure Application Gatway Ingress Controller, you are required to input 
a Base64 encoded JSON string of a service principal for the selected subscription.

You can generate one with command `az ad sp create-for-rbac --sdk-auth | base64 -w0`.

### Database Instance

Optional.

If you are going to apply a database with {{ site.data.var.wlsFullBrandName }},
you must have an existing database instance to use.  

This template builds with datasource driver for three popular Azure databases: [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), 
[Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/), [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal).  If you do not have an instance, please
create one from the Azure portal. 

If you want to use other databse, you must provide a running data server, 
make sure the database is accessible from Azure. Then specify a datasource driver url via `dbDriverLibrariesUrls `, datasource driver name via `dbDriverName` and test table name `dbTestTableName`, see [Database](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/#database) for more information.

### Custom DNS

Optional.

{% include sub-template-dnszone.md %}

{% include sub-template-create-update-wls-on-aks.md %}

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`. 
This section shows the commands to create WebLogic cluster on AKS.

Set resource group name, should be the one running your AKS cluster.

```shell
resourceGroupName="hello-wls-aks"
```

### Validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose \
  --resource-group ${resourceGroupName} \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}mainTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose \
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
