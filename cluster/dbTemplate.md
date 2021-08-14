{% include variables.md %}

# Apply Database ARM Template to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with an existing Azure database using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The database ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Database Instance

To apply configure a database with {{ site.data.var.wlsFullBrandName }},
you must have an existing database instance to use.  This template
supports three popular Azure databases: [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), [Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/) and [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal).  If you do not have an instance, please
create one from the Azure portal.

### Apply multiple databases 

You can deploy different databases using the database ARM template, by changing the ARM parameters file and invoking the template again with Azure CLI.

To apply multiple databases, you have to remove the previous virtual machine extension. Last ARM parameters file is cached, it will block you from configuring the new database.

Use the following command to remove virtual machine extension:

```bash
# remove existing vm extension
az vm extension delete -g ${yourResourceGroup} --vm-name ${adminVMName} --name newuserscript
```

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the database ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   We must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and database instance. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `adminVMName`| At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `databaseType`| Must be one of `postgresql`, `oracle` or `sqlserver` |
| `dbPassword`| See below for details. |
| `dbUser` | See below for details. |
| `dsConnectionURL`| See below for details. |
| `jdbcDataSourceName`| Must be the JNDI name for the JDBC DataSource. |
| `location` | Must be the same region into which the server was initially deployed. |
| `wlsPassword` | Must be the same value provided at deployment time. |
| `wlsUserName` | Must be the same value provided at deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

### Obtain the JDBC Connection String, Database User, and Database Password

The parameter `dsConnectionURL` stands for JDBC connection string. The connection string is database specific.

#### Oracle Database:

The following is the format of the JDBC connection string for Oracle Database:

```bash
jdbc:oracle:thin:@HOSTNAME:1521/DATABASENAME
```

For example:

```bash
jdbc:oracle:thin:@benqoiz.southeastasia.cloudapp.azure.com:1521/pdb1
```

#### Azure Database for PostgreSQL:

Deploy an Azure Database PostgreSQL as described in [Create an Azure Database for PostgreSQL server in the Azure portal](https://docs.microsoft.com/en-us/azure/postgresql/quickstart-create-server-database-portal).

1. Access the [Azure portal](https://portal.azure.com), and go to the service instance.

2. Click **Connection Strings** under **Settings**.

3. Locate the **JDBC** section and click the copy icon on the right to copy the JDBC connection string to the clipboard. The JDBC connection string will be similar to the following:

```bash
jdbc:postgresql://20191015cbfgterfdy.postgres.database.azure.com:5432/{your_database}?user=jroybtvp@20191015cbfgterfdy&password={your_password}&sslmode=require
```

When passing this value to the ARM template, remove the database user and password values from the connection string, and let them be the parameters `dbUser` and `dbPassword`. In the above JDBC connection string sample, the value for `dsConnectionURL` argument after removing the database user and password, will be:

```bash
jdbc:postgresql://20191015cbfgterfdy.postgres.database.azure.com:5432/{your_database}?sslmode=require
```

Finally, replace `{your_database}` with the name of your database, typically `postgres`.

#### Azure SQL Server

Deploy Azure SQL Server as described in [Create a single database in Azure SQL Database using the Azure portal, PowerShell, and Azure CLI](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-single-database-get-started?tabs=azure-portal).

1. Access the [Azure portal](https://portal.azure.com) and go to the service instance.

2. Click **Connection Strings** under **Settings**.

3. Locate the **JDBC** section and click the copy icon on the right to copy the JDBC connection string to the clipboard. The JDBC connection string will be similar to the following:

```bash
jdbc:sqlserver://rwo102804.database.windows.net:1433;database=rwo102804;user=jroybtvp@rwo102804;password={your_password_here};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;
```

When passing this value to the ARM template, remove the database user and password values, let them be the parameters `dbUser` and `dbPassword`. In the above JDBC connection string sample, the value for `dsConnectionURL` argument after removing the database user and password, will be:

```bash
jdbc:sqlserver://rwo102804.database.windows.net:1433;database={your_database};encrypt=true;tr
```

Finally, replace `{your_database}` with the name of your database.

#### Example Parameters JSON

Here is a fully filled out parameters file.   Note that we did not include `adminVMName`.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation":{
            "value": "{{ armTemplateBasePath }}"
          },
        "location": {
          "value": "eastus"
        },
        "databaseType": {
          "value": "postgresql"
        },
        "dsConnectionURL": {
          "value": "jdbc:postgresql://ejb060801p.postgres.database.azure.com:5432/postgres?sslmode=require"
        },
        "dbPassword": {
          "value": "Secret123!"
        },
        "dbUser": {
          "value": "postgres@ejb060801p"
        },
        "jdbcDataSourceName": {
          "value": "jdbc/ejb060801p"
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

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with the specified database.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/dbTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/dbTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```json
{
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Resources/deployments/db",
  "location": null,
  "name": "db",
  "properties": {
    "correlationId": "6fc805b9-1c47-4b32-b9b0-59745a21e559",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-admin-0602",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Resources/deployments/3b35b279-0e94-5264-85f5-0d9d662f8a38",
        "resourceGroup": "oraclevm-admin-0602",
        "resourceName": "3b35b279-0e94-5264-85f5-0d9d662f8a38",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT17.4377546S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-0602/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-admin-0602"
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
      "_artifactsLocationDbTemplate": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      }
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "databaseType": {
        "type": "String",
        "value": "postgresql"
      },
      "dbPassword": {
        "type": "SecureString"
      },
      "dbUser": {
        "type": "String",
        "value": "weblogic@oraclevm"
      },
      "dsConnectionURL": {
        "type": "String",
        "value": "jdbc:postgresql://oraclevm.postgres.database.azure.com:5432/postgres"
      },
      "jdbcDataSourceName": {
        "type": "String",
        "value": "jdbc/WebLogicCafeDB"
      },
      "location": {
        "type": "String",
        "value": "eastus"
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
    "templateHash": "6381424766408193665",
    "templateLink": null,
    "timestamp": "2020-06-02T06:05:03.141828+00:00"
  },
  "resourceGroup": "oraclevm-admin-0602",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify Database Connection

Follow the steps to check if the database has successfully been connected.

* Visit the {{ site.data.var.wlsFullBrandName }} Admin console.
* In the left navigation pane, expand the **Services** tree node and the **DataSources** child node.
* Select the row for the JDBC database name, for example `jdbc/WebLogicDB`.
* Select the **Monitoring** tab and the **Testing** sub-tab.
* Select `admin` and select **Test Data Source**
* If the database is enabled, you will see a message similar to "Test of jdbc/WebLogicDB on server admin was successful."
