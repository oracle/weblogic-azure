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