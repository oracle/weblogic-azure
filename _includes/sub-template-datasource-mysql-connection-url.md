#### MySQL

Deploy Azure Database for MySQL as described in [Create an Azure Database for MySQL server by using the Azure portal](https://docs.microsoft.com/en-us/azure/mysql/single-server/quickstart-create-mysql-server-database-using-azure-portal).

1. Access the [Azure portal](https://portal.azure.com) and go to the service instance.

2. Note that, for Azure Database for MySQL, you need to add @\<servername> to the admin user name, similar to `weblogic@contoso`.

3. Click **Connection Strings** under **Settings**.

4. Locate the **JDBC** section and click the copy icon on the right to copy the JDBC connection script to the clipboard. The JDBC connection string will be the value of **url**, similar to the following:

```bash
jdbc:mysql://contoso.mysql.database.azure.com:3306/{your_database}?useSSL=true&requireSSL=false
```

Next, replace `{your_database}` with the name of your database.

You have to append arguments according to the WLS version you are using.