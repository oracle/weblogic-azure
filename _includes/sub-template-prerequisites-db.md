### Database Instance (optional)

If you are going to apply a database with {{ site.data.var.wlsFullBrandName }},
you must have an existing database instance to use.

This template builds with data source driver for three popular Azure databases: [Oracle](https://ms.portal.azure.com/#blade/Microsoft_Azure_Marketplace/MarketplaceOffersBlade/selectedMenuItemId/home/searchQuery/oracle%20database), 
[Azure SQL Server](https://docs.microsoft.com/en-us/azure/azure-sql/), [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart?WT.mc_id=gallery&tabs=azure-portal).  If you do not have an instance, please create one from the Azure portal. 

If you want to use any other databse, you must provide a running database instance.
Make sure the database is accessible from Azure. Specify a data source driver url via `dbDriverLibrariesUrls `, data source driver name via `dbDriverName` and test table name `dbTestTableName`, see [Database](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/#database) for more information.

