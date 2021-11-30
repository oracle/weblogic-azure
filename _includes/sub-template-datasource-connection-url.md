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