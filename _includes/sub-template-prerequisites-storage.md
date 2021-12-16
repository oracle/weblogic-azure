### Azure Storage account 

If you are deploying a Java EE application or using your own JDBC data source driver, you are required to 
have application packages and JDBC libraries uploaded to a blob storage container in an Azure Storage Account.

To create Azure Storage Account and blobs, follow the steps in [Quickstart: Upload, download, and list blobs with the Azure portal](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal).

Upload your application packages (.jar, .war, .ear files) to the blob.

Upload your JDBC drivers (.jar files) to the blob.

