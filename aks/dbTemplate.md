<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Apply Database ARM Template to {{ site.data.var.wlsFullBrandName }} that is running on AKS

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with an existing Azure database using Azure CLI. 

You can invoke the database ARM template to:

  - Create a new datasource connection, you can have multiple datasource connections in your cluster.

  - Update an existing datasource connection

  - Delete an existing datasource connection

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### Azure Managed Indentify

You are required to input the ID of a user-assigned managed identity. 

Follow this [guide](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal) 
to create a user-assigned managed identity.

To obtain ID of the indentify: go to Azure Portal; open the identity **Overview** page; click **JSON View** and copy the **Resource ID**.

### WebLogic Server Instance

The database ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

If you are using your own datasource driver, make sure the datasource driver is uploaded during the WebLogic Server instance provisioning. 

You can create a WebLogic cluster with datasource driver library with steps:

  - Open [WebLogic on AKS marketplace offer](https://portal.azure.com/?feature.customPortal=false#create/oracle.20210620-wls-on-aks20210620-wls-on-aks)

  - Input values to **Basics** and **Config AKS cluster** blade

  - In the Database blade, select **Yes** to connect to database. For **Choose databse type**, select **Other**, upload datasource driver in **Datasource driver**.

  - Finish other inputs, create **Review + create** to provison a cluster.

You will get a WebLogic cluster with your datasource driver built in the image.

### Database Instance

To apply a database with {{ site.data.var.wlsFullBrandName }},
you must have an existing database instance to use.

#### Work with built-in datasource driver

The marketplace offer ships with database driver for [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), [Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/) and [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal).  You can invoke the dbTemplate to create datasource connection for those database. 
If you do not have an instance, please create one from Azure portal.

#### Bring your own datasource driver

Besides [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), [Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/) and [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal), you are able to create datasource connection using other databases, such as [IBM Informix](https://www.ibm.com/products/informix) and [MariaDB](https://mariadb.org/), but you have to follow those steps to achieve that:

  - Create your database server, and make sure the database is accessible from Azure.

  - Ship your database driver to WebLogic cluster. The only approach to upload a datasource driver is using [marketplace offer](https://portal.azure.com/?feature.customPortal=false#create/oracle.20210620-wls-on-aks20210620-wls-on-aks). The offer enables you to bring your own datasource driver. See [WebLogic Server Instance](#webLogic-server-instance)

  - Invoke the dbTemplate to update an existing datasource connection or create another new datasource connection.

### Apply multiple datasource

You may want to enable multiple datasource in your cluster for the following usage:
  - Create multiple datasource connections using the same database
  - Create multiple datasource connections using different databases

You can deploy different datasource connections using the database ARM template, by changing the ARM parameters file and invoking the template again with Azure CLI.

To deploy datasource using your own datasource driver, we assume the datasource driver have been uploaded to the cluster. See [WebLogic Server Instance](#webLogic-server-instance)

## Prepare the Parameters JSON file

| Advanced parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| Required. See below for details. |
| `aksClusterName`| Required. Name of the AKS cluster. Must be the same value provided at deployment time. |
| `databaseType`| Optinal. Defaults by `oracle`. <br> `oracle`: will provision a [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database) datasoruce connection. <br> `postgresql`: will provision a [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal) datasource connection.<br> `sqlserver`: will provision a [Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/) datasource connection. |
| `dbConfigurationType`| Optinal. Defaults by `createOrUpdate`. <br> `createOrUpdate`: the deployment will create a new datasource connection if there is no  datasource has the same name with `jdbcDataSourceName`, otherwise, will update the expected datasource with new inputs. <br> `delete`: the deployment will delete a datasource connection that has name `jdbcDataSourceName` |
| `dbGlobalTranPro` | Optinal. Defaults by `OnePhaseCommit`. The transaction protocol (global transaction processing behavior) for the data source. You may use one from: `["TwoPhaseCommit", "LoggingLastResource", "OnePhaseCommit", "None"]`|
| `dbPassword`| Required. Password for the datasource connection. |
| `dbUser`| Required. User id for the datasource connection. |
| `dsConnectionURL` | Required. JDBC connection string. |
| `identity` | Required. Azure user managed identity used, make sure the identity has permission to create/update/delete Azure resources. It's recommended to assign "Contributor" role. |
| `jdbcDataSourceName` | Required. Specify public port of the custom T3 channel in WebLoigc cluster. |
| `wlsDomainUID` | Required. UID of the domain that you are going to update. Make sure it's the same with the initial cluster deployment. |
| `wlsPassword` | Required. Password for WebLogic Administrator. Make sure it's the same with the initial cluster deployment. |
| `wlsUserName` | Required. User name for WebLogic Administrator. Make sure it's the same with the initial cluster deployment. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

### Obtain the JDBC Connection String, Database User, and Database Password

The parameter `dsConnectionURL` stands for JDBC connection string. The connection string is database specific.

{% include sub-template-datasource-connection-url.md %}

#### Example Parameters JSON

```json
{
    "_artifactsLocation": {
        "value": "{{ armTemplateBasePath }}"
    },
    "aksClusterName": {
      "value": "aks-sample"
    },
    "databaseType": {
      "value": "postgresql"
    },
    "dbConfigurationType": {
      "value": "createOrUpdate"
    },
    "dbPassword": {
        "value": "Secret123!"
    },
    "dbUser": {
        "value": "postgres@sampledb"
    },
    "dsConnectionURL": {
        "value": "jdbc:postgresql://sampledb.postgres.database.azure.com:5432/postgres?sslmode=require"
    },
    "identity": {
      "value": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/subscription-id/resourceGroups/samples/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azure_wls_aks": {}
        }
      }
    },
    "jdbcDataSourceName": {
      "value": "jdbc/WebLogicDB"
    },
    "wlsDomainUID": {
      "value": "sample-domain1"
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

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with the specified database.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### Validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/dbTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/dbTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

For a successful deployment, you should find `"provisioningState": "Succeeded"` in your output.

## Verify Database Connection

Follow the steps to check if the database has successfully been connected.

* Visit the {{ site.data.var.wlsFullBrandName }} Admin console.
* In the left navigation pane, expand the **Services** tree node and the **DataSources** child node.
* Select the row for the JDBC database name, for example `jdbc/WebLogicDB`.
* Select the **Monitoring** tab and the **Testing** sub-tab.
* Select `admin` and select **Test Data Source**
* If the database is enabled, you will see a message similar to "Test of jdbc/WebLogicDB on server admin was successful."