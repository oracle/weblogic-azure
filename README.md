# About WebLogic on Microsoft Azure

As part of a broad-ranging partnership between Oracle and Microsoft, this project offers support for running Oracle WebLogic Server in the Azure Virtual Machines and Azure Kubernetes Service (AKS). The partnership includes joint support for a range of Oracle software running on Azure, including Oracle WebLogic, Oracle Linux, and Oracle DB, as well as interoperability between Oracle Cloud Infrastructure (OCI) and Azure. 

## Installation

The [Azure Marketplace WebLogic Server Offering](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=WebLogic) offers a simplified UI and installation experience over the full power of the Azure Resource Manager (ARM) template.

## Documentation

Please refer to the README for [documentation on WebLogic Server running on an Azure Kubernetes Service](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/)

Please refer to the README for [documentation on WebLogic Server running on an Azure Virtual Machine](https://docs.oracle.com/en/middleware/standalone/weblogic-server/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7)

## Deployment Description

### WLS on VMs

#### Oracle WebLogic Server Single Node

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition (WLS) without domain configuration.

* The offer includes a choice of operating system, JDK, Oracle WebLogic Server versions.
   * OS: Oracle Linux or Red Hat Enterprise Linux
   * JDK: Oracle JDK 8, or 11
   * WLS version: 12.2.1.3, 12.2.1.4, 14.1.1.0
* Computing resources
    * A VM with the following configurations:
        * Operating system as described in the selected base image.
        * Choice of VM size.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. 
    * A network security group.
    * A network interface.
    * A public IP address assigned to the network interface.
* Storage resources
    * An Azure Storage Account to store the VM diagnostics profile.
* Key Software components
    * Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * In addition to the database drivers that come standard with WLS, the offer includes the most recent supported PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 

#### Oracle WebLogic Server with Admin Server

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition (WLS) with a domain and the Administration Server set up.

* The offer includes a choice of operating system, JDK, Oracle WebLogic Server versions.
   * OS: Oracle Linux or Red Hat Enterprise Linux
   * JDK: Oracle JDK 8, or 11
   * WLS version: 12.2.1.3, 12.2.1.4, 14.1.1.0
* Computing resources
    * A VM to run the Administration Server with the following configuration.
        * Operating system as described in the selected base image.
        * Choice of VM size.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * A network security group if you select to create a new virtual network.
    * A network interface.
    * A public IP address assigned to the network interface if you select to create a new virtual network.
* Storage resources
    * An Azure Storage Account and a file share named `wlsshare`. The mount point is `/mnt/wlsshare`.
    * The storage account is also used to store the diagnostics profile of the VM.
    * A private endpoint in the same subnet with the VM, which allows the VM to access the file share.
* Key software components
    * Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * In addition to the database drivers that come standard with WLS, the offer includes the most recent supported PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 
    * A WLS domain with the Administration Server up and running. Sign in to the Administration Server is with the Administrator user name and credentials provided to the offer. The default domain name is `adminDomain`, the domain path is `/u01/domains/adminDomain/`. You are able to access the Administration Server and manage the domain via URL `http://<admin-vm-hostname>:7001/console/`. By default, the offer configures the Administration Server with a self-signed TLS certificate. You are able to access it with HTTPS `https://<admin-vm-hostname>:7002/console/`.
    * If you select to configure WebLogic Administration Console on HTTPS (Secure) port, TLS/SSL termination is performed with your own TLS/SSL certificate. The offer sets up the Administration Server with identity key store and trust key store provided to the offer. The default secure port is `7002`. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
* Database connectivity
    * The offer provides database connectivity using username/password or Azure passwordless database access.
    * Username/password connections to existing Azure database for PostgreSQL, Oracle database, Azure SQL or MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database to user managed identity of VM.
* Access URLs
    * Access to the Administration Server via HTTP. If you enable traffic to the Administration Server, the HTTP URLs is `http://<admin-vm-hostname>:7001/console/`.
    * Access to the Administration Server via HTTPS. If you enable traffic to the Administration Server, the HTTPS URL is different for the following scenarios:
        * With TLS/SSL termination enabled and custom DNS enabled, the HTTP URLs is `http://<admin-label>.<dns-zone-name>:7002/console/`. 
        * With on TLS/SSL termination enabled,  the HTTP URLs is `http://<admin-vm-hostname>:7002/console/`. 

#### Oracle WebLogic Server Cluster

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition (WLS) with a domain, the Administration Server and a configured cluster set up.

* The offer includes a choice of operating system, JDK, Oracle WebLogic Server versions.
   * OS: Oracle Linux or Red Hat Enterprise Linux
   * JDK: Oracle JDK 8, or 11
   * WLS version: 12.2.1.3, 12.2.1.4, 14.1.1.0
* Computing resources
    * VMs with the followings configurations:
        * A VM to run the Administration Server and an arbitrary number of VMs to run Managed Servers.
        * VMs to run Coherence Cache servers.
        * Choice of VM size.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * A network security group if you select to create a new virtual network.
    * Network interfaces for VMs.
    * Public IP addresses assigned to the network interfaces of admin server and managed servers.
    * A public IP assigned to Application Gateway if you select to enable Application Gateway.
* Load Balancer
    * An Azure Application Gateway if you select to enable it. You can upload TLS/SSL certifiacte or use the certificates stored in a key vault. Otherwise, you can assign an auto-generated self-signed certificate to the application gateway.
* High Availability
    * An Azure Availability Set for the VMs.
* Key software components
    * Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * In addition to the database drivers that come standard with WLS, the offer includes the most recent supported PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 
    * A WLS domain with the Administration Server up and running. Sign in to the Administration Server is with the Administrator user name and credentials provided to the offer. The default domain name is `adminDomain`, the domain path is `/u01/domains/adminDomain/`. You are able to access the Administration Server and manage the domain via URL `http://<admin-vm-hostname>:7001/console/`. By default, the offer configures the Administration Server with a self-signed TLS certificate. You are able to access it with HTTPS `https://<admin-vm-hostname>:7002/console/`.
    * A configured cluster with Managed Servers running. The number of managed servers is specified in the UI when deploying the offer.
    * Coherence Cache. If you select to enable Coherence Cache, the offer creates a data tier configured with Managed Coherence cache servers.
* Database connectivity
    * The offer provides database connectivity using username/password or Azure passwordless database access.
    * Username/password connections to existing Azure database for PostgreSQL, Oracle database, Azure SQL or MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database to user managed identity of VM.
* Access URLs
    * Access to the Administration Server via HTTP. If you enable traffic to the Administration Server, the HTTP URLs is `http://<admin-vm-hostname>:7001/console/`.
    * Access to the Administration Server via HTTPS. If you enable traffic to the Administration Server, the HTTPS URL is different for the following scenarios:
        * With TLS/SSL termination enabled and custom DNS enabled, the HTTP URLs is `http://<admin-label>.<dns-zone-name>:7002/console/`. 
        * With on TLS/SSL termination enabled,  the HTTP URLs is `http://<admin-vm-hostname>:7002/console/`. 
    * Access to cluster and your application via HTTP. If you enable Application Gateway, the HTTP URLs is `http://<app-gateway-hostname>/<app-context-path>/`.
    * Access to cluster and your application via HTTPS:
        * If you enable Application Gateway with signed certificate and custom DNS, the HTTPS URLs is `https://<application-label>.<dns-zone-name>/<app-context-path>/`.
        * If you enable Application Gateway with self-signed certificate, the HTTPS URLs is `https://<app-gateway-hostname>/<app-context-path>/`.

#### Oracle WebLogic Server Dynamic Cluster

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition (WLS) with a domain, the Administration Server, and a dynamic cluster set up.

* The offer includes a choice of operating system, JDK, Oracle WebLogic Server versions.
   * OS: Oracle Linux or Red Hat Enterprise Linux
   * JDK: Oracle JDK 8, or 11
   * WLS version: 12.2.1.3, 12.2.1.4, 14.1.1.0
* The offer includes the choice of the following Oracle HTTP Server (OHS) base images
   * OS: Oracle Linux
   * OHS version 12.2.1.4.0
* Computing resources
    * VMs for Oracle WebLogic Server:
        * A VM to run the Administration Server and an arbitrary number of VMs to run Managed Servers.
        * VMs to run Coherence Cache servers.
        * Operating system as described in the selected base image.
        * Choice of VM size.
        * An OS disk attached to the VM.
    * VMs for Oracle HTTP Server:
        * A VM to run the Oracle HTTP Server.
        * Choice of VM size.
        * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * A network security group if you select to create a new virtual network.
    * Network interfaces for VMs.
    * Public IP addresses assigned to the network interfaces of the admin server and managed servers.
    * Public IP addresses assigned to the network interfaces of cache machines if you select to create a new virtual network and enable Coherence Cache.
    * A public IP assigned to Oracle HTTP Server if you select to enable it.
* Load Balancer
    * An Oracle HTTP Server if you select to enable it. You can upload TLS/SSL certifiacte or use the certificates stored in a key vault to configure HTTPS.
* Storage resources
    * An Azure Storage Account and a file share named `wlsshare`. The mount point is `/mnt/wlsshare`.
    * The storage account is also used to store the diagnostics profile of the VMs.
    * A private endpoint in the same subnet with the VM, which allows the VM to access the file share.
* Key software components for Oracle WebLogic Server
    * Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * In addition to the database drivers that come standard with WLS, the offer includes the most recent supported PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 
    * A WLS domain with the Administration Server up and running. Sign in to the Administration Server is with the Administrator user name and credentials provided to the offer. The default domain name is `adminDomain`, the domain path is `/u01/domains/adminDomain/`. You are able to access the Administration Server and manage the domain via URL `http://<admin-vm-hostname>:7001/console/`. By default, the offer configures the Administration Server with a self-signed TLS certificate. You are able to access it with HTTPS `https://<admin-vm-hostname>:7002/console/`.
    * A dynamic cluster with spcified number of Managed Servers running. The number of Managed servers is specified by **Initial Dynamic Cluster Size**. The cluster size is specified by **Maximum Dynamic Cluster Size**.
    * If you select to configure WebLogic Administration Console on HTTPS (Secure) port, TLS/SSL termination is performed with your own TLS/SSL certificate. The offer sets up the Administration Server with identity key store and trust key store provided to the offer. The default secure port is `7002`. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
    * Coherence Cache. If you select to enable Coherence Cache, the offer creates a data tier configured with Managed Coherence cache servers.
* Key software components for Oracle HTTP Server
    * Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/ohs/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * A domain is configured based on the node manager user name and credentials provided by the user. The default domain name is `ohsStandaloneDomain`, the domain path is `/u01/domains/ohsStandaloneDomain/`.
    * An Oracle HTTP Server Component with default name `ohs_component`.
    * If you select to configure your own TLS/SSL certificate, TLS/SSL termination is enabled.  The offer sets up the Oracle HTTP Server with the provided identity key store and trust key store. The default secure port is `4444`. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
* Database connectivity
    * The offer provides database connectivity using username/password or Azure passwordless database access.
    * Username/password connections to existing Azure database for PostgreSQL, Oracle database, Azure SQL or MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database to user managed identity of VM.
* Access URLs
    * Access to the Administration Server via HTTP. If you enable traffic to the Administration Server, the HTTP URLs is `http://<admin-vm-hostname>:7001/console/`.
    * Access to the Administration Server via HTTPS. If you enable traffic to the Administration Server, the HTTPS URL is different for the following scenarios:
        * With TLS/SSL termination enabled and custom DNS enabled, the HTTP URLs is `http://<admin-label>.<dns-zone-name>:7002/console/`. 
        * With on TLS/SSL termination enabled,  the HTTP URLs is `http://<admin-vm-hostname>:7002/console/`. 
    * Access to cluster and your application via HTTP. If you enable Oracle HTTP Server, the HTTP URLs is `http://<ohs-server-hostname>:7777/<app-context-path>/`. Replace `7777` with your value if you change the default port.
    * Access to cluster and your application via HTTPS. If you enable Oracle HTTP Server and custom DNS, the HTTPS URLs is `https://<load-balancer-label>.<dns-zone-name>:4444/<app-context-path>/`. Replace `4444` with your value if you change the default port.

### WLS on AKS

The offer provisions the following Azure resources and an Oracle WebLogic Server Enterprise Edition (WLS) with a domain, the Administration Server and a dynamic cluster set up.


* The offer includes the choice of the following Oracle WebLogic Server container images
    * Images from Oracle Container Registry (General or Patched images)
       * OS: Oracle Linux or Red Hat Enterprise Linux
       * JDK: Oracle JDK 8, or 11
       * WLS version: 12.2.1.3, 12.2.1.4, 14.1.1.0
       * You can specify any arbitrary docker image tag that is available from Oracle Container Registry. 
    * Images from your own Azure Container Registry.
* Computing resources
    * Azure Kubernetes Service cluster
        * Dynamically created AKS cluster with
           * Choice of Node count.
           * Choice of Node size.
           * Network plugin: Azure CNI.
        * You can also bring your own AKS cluster
    * An Azure Container Registry. You can also bring your own container registry. The registry is used to store the WLS and application image.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * Public IP addresses assigned to the managed load balancer and Azure Application Gateway, if selected.
* Load Balancer
    * An Azure Application Gateway if you select to enable it. You can upload TLS/SSL certificate or use the certificates stored in a key vault. Otherwise, assign a self-signed certificate to the application gateway.
    * Load balancer services if you select to enable it.
* Storage resources
    * An Azure Storage Account and a file share named `weblogic` if you select to create Persistent Volume using Azure File share service. The mount point is `/shared`.
* Monitoring resources
    * Azure Container Insights and workspace for it if you select to enable Container insights.
* Key software components
    * Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The `ORACLE_HOME` is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version as described in the selected base image. The `JAVA_HOME` is `/u01/app/jdk/jdk-${version}`.
    * A WLS domain with the Administration Server up configured based on the provided Administrator user name and credentials. The default domain name is `sample-domain1`, the domain path is `/u01/domains/sample-domain1/`.
    * A dynamic cluster with Managed Servers running. The number of Managed Servers is specified by **Number of WebLogic Managed Server replicas**, and cluster size is specified by **Maximum dynamic cluster size**.
    * TLS/SSL termination if you select to configure WebLogic Administration Console on HTTPS (Secure) port, with your own TLS/SSL certificate. The offer sets up the Administration Server with the provided identity key store and trust key store. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
* Database connectivity
    * The offer provides database connectivity using username/password or Azure passwordless database access.
    * Username/password connections to existing Azure database for PostgreSQL, Oracle database, Azure SQL or MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database.
* Access URLs
    * If you select to enable Application Gateway Ingress Controller:
        * Access the cluster:
            * The HTTP URLs is `http://<app-gateway-hostname>/<app-context-path>/`.
            * If you enable Application Gateway with signed certificate and enable custom DNS, the HTTPS URLs is `https://<application-label>.<dns-zone-name>/<app-context-path>/`.
            * If you enable Application Gateway with self-signed certificate, the HTTPS URLs is `https://<app-gateway-hostname>/<app-context-path>/`.
        * Access the Administration Server:
            * If you select to create ingress for the Administration Server, the HTTP URL is `http://<app-gateway-hostname>/console/`.
            * If you select to create ingress for the Administration Server, enable Application Gateway with self-signed certificate and enable custom DNS, the HTTPs URL is `https://<admin-label>.<dns-zone-name>/console/`. 
    * If you select to enable Azure Load Balancer Service:
        * Access the cluster:
            * Configure the service name and port.
            * The HTTP URLs is `http://<load-balancer-public-ip-for-cluster>:<port>/<app-context-path>/`.
            * If you enable WLS TLS/SSL termination and enable custom DNS, the HTTPS URLs is `https://<application-label>.<dns-zone-name>:<port>/<app-context-path>/`.
        * Access the Administration Server:
            * Configure the service name and port.
            * The HTTP URL to access the Administration Server is `http://<load-balancer-public-ip-for-admin-server>:<port>/console/`.
            * If you enable WLS TLS/SSL termination and enable custom DNS, the HTTPs URL is `https://<admin-label>.<dns-zone-name>:<port>/console/`.
## Examples

To get details of how to run Oracle WebLogic Server on Azure Virtual Machines refer to the blog [WebLogic on Azure Virtual Machines Major Release Now Available](https://blogs.oracle.com/weblogicserver/weblogic-on-azure-virtual-machines-major-release-now-available).

To get details of how to run Oracle WebLogic Server on Azure Kubernetes Service refer to the blog [Run Oracle WebLogic Server on the Azure Kubernetes Service](https://blogs.oracle.com/weblogicserver/run-oracle-weblogic-server-on-the-azure-kubernetes-service).

## Issues

Issue related to Oracle WebLogic Server on Microsoft Azure implementation are tracked ain the [Issues tab](https://github.com/oracle/weblogic-azure/issues) of the GitHub project.


## Contributing

This project welcomes contributions from the community. Before submitting a pull
request, please [review our contribution guide](./CONTRIBUTING.md).

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security
vulnerability disclosure process.

## License

Copyright (c) 2021, Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.
