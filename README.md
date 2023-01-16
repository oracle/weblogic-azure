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

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition without domain configuration.

* Oracle WebLogic Server base images
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3.
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6.
* Computing resources
    * A VM with the following configurations:
        * The operation system is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the operation system is Oracle Linux 7.3.
        * VM size.
        * VM administrator authentication type and the related credential.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. 
    * A network security group.
    * A network interface.
    * A public IP address assigned to the network interface.
* Storage resources
    * An Azure Storage Account to store the VM diagnostics profile.
* Oracle WebLogic Server components
    * Oracle WebLogic Server Enterprise Edition. The version is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is 12.2.1.3.0. The oracle home is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version is consistent with the selected base image, e.g., if a user selects **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is JDK 8. The Java home is `/u01/app/jdk/jdk-${version}`.
    * The recent PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 

#### Oracle WebLogic Server with Admin Server

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition with a domain and the Administration Server set up.

* Oracle WebLogic Server base images
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3.
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6.
* Computing resources
    * A VM named `adminVM` with the following configurations:
        * The operation system is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the operation system is Oracle Linux 7.3.
        * VM size.
        * VM administrator authentication type and the related credential.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * A network security group if you select to create a new virtual network.
    * A network interface.
    * A public IP address assigned to the network interface if you select to create a new virtual network.
    * A public DNS Zone if user selects to enable custom DNS and create a new DNS zone. You can also bring your own DNS Zone.
    * An A record (Alias record to IPV4 address) to the VM if you select to enable custom DNS.
* Storage resources
    * An Azure Storage Account and a file share named `wlsshare`. The mount point is `/mnt/wlsshare`.
    * The storage account is also used to store the diagnostics profile of the VM.
    * A private endpoint in the same subnet with the VM, which allows the VM to access the file share.
* Security
    * An Azure Key Vault to store certificates if you select to upload TLS/SSL certificates.
* Oracle WebLogic Server components
    * Oracle WebLogic Server Enterprise Edition. The version is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is 12.2.1.3.0. The oracle home is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version is consistent with the selected base image, e.g., if a user selects **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is JDK 8. The Java home is `/u01/app/jdk/jdk-${version}`.
    * The recent PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 
    * An domain with the Administration Server up configured based on the inputting Administrator user name and credentials. The default domain name is `adminDomain`, the domain path is `/u01/domains/adminDomain/`. You are able to access the Administration Server and manage the domain via URL `http://<vm-ip-address>:7001/console/`. By default, the offer configures the Administration Server with a self-signed certificate, you are able to access it with HTTPS `https://<vm-ip-address>:7002/console/`.
    * TLS/SSL termination if you select to configure WebLogic Administration Console on HTTPS (Secure) port, with your own TLS/SSL certificate. The offer sets up the Administration Server with the inputting identity key store and trust key store, and the default secure port is `7002`. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
* Database connectivity
    * Password connections to exiting Azure database for PostgreSQL, Oracle database, Azure SQL and MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database to user managed identity of VM.
* Access URLs
    * Access to the Administration Server via HTTP. If you enable traffic to the Administration Server, the HTTP URLs is `http://<vm-ip-address>:7001/console/`.
    * Access to the Administration Server via HTTPS. If you enable traffic to the Administration Server, the HTTPS URL is different for the following scenarios:
        * With TLS/SSL termination enabled and custom DNS enabled, the HTTP URLs is `http://<admin-label>.<dns-zone-name>:7002/console/`. 
        * With on TLS/SSL termination enabled,  the HTTP URLs is `http://<vm-ip-address>:7002/console/`. 

#### Oracle WebLogic Server Cluster

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition with a domain and the Administration Server set up.

* Oracle WebLogic Server base images
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3.
    * The **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4** image has WLS 12.2.1.3.0 and JDK 8 on Oracle Linux 7.4.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Oracle Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Oracle Linux 7.6.
    * The **WebLogic Server 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 12.2.1.4.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 8 on Red Hat Enterprise Linux 7.6.
    * The **WebLogic Server 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6** image has WLS 14.1.1.0.0 and JDK 11 on Red Hat Enterprise Linux 7.6.
* Computing resources
    * VMs with the followings configurations:
        * A VM to run the Administration Server named `adminVM` and several VMs named `mspVM${index}` to run Managed Servers, the maximum VM nunmber is 5. You can add nodes following [the post deployment guidance](https://oracle.github.io/weblogic-azure/cluster/addnode.html).
        * VMs to run Coherence Cache servers. You can add nodes for cache server following [the post deployment guidance](https://oracle.github.io/weblogic-azure/cluster/addnode-coherence.html).
        * The operation system is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the operation system is Oracle Linux 7.3.
        * VM size.
        * VM administrator authentication type and the related credential.
    * An OS disk attached to the VM.
* Network resources
    * A virtual network and a subnet. You can also select to bring your own virtual network.
    * A network security group if you select to create a new virtual network.
    * Network interfaces for VMs.
    * A public IP address assigned to the network interface of `adminVM` if you select to create a new virtual network.
    * Public IP addresses assigned to the network interfaces of `mspVM${index}` if you select to create a new virtual network.
    * Public IP addresses assigned to the network interfaces of cache machines if you select to create a new virtual network and enable Coherence Cache.
    * A public IP assigned to Application Gateway if you select to enable Application Gateway.
    * A public DNS Zone if user selects to enable custom DNS and create a new DNS zone. You can also bring your own DNS Zone.
    * An A record (Alias record to IPV4 address) to the VM if you select to enable custom DNS.
    * A CNAME record to the application gateway if you select to enable custom DNS and enable Azure Application Gateway.
* Load Balancer
    * An Azure Application Gateway if you select to enable it. You can upload TLS/SSL certifiacte or use the certificates stored in a key vault. Otherwise, assign a self-signed certificate to the application gateway.
* Storage resources
    * An Azure Storage Account and a file share named `wlsshare`. The mount point is `/mnt/wlsshare`.
    * The storage account is also used to store the diagnostics profile of the VMs.
    * A private endpoint in the same subnet with the VM, which allows the VM to access the file share.
* Security
    * An Azure Key Vault will be created for the following scenarios:
        * Select to upload certificates for WLS.
        * Select to upload certificates for Application Gateway.
        * Select to enable Application Gateway with self-signed certificate.
* High Availability
    * An Azure Availability Set for the VMs.
* Oracle WebLogic Server components
    * Oracle WebLogic Server Enterprise Edition. The version is consistent with the selected base image, e.g., if you select **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is 12.2.1.3.0. The oracle home is `/u01/app/wls/install/oracle/middleware/oracle_home`.
    * Oracle JDK. The version is consistent with the selected base image, e.g., if a user selects **WebLogic Server 12.2.1.3.0 and JDK 8 on Oracle Linux 7.3**, the version is JDK 8. The Java home is `/u01/app/jdk/jdk-${version}`.
    * The recent PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in `/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/`. 
    * An domain with the Administration Server up configured based on the inputting Administrator user name and credentials. The default domain name is `wlsd`, the domain path is `/u01/domains/wlsd/`. You are able to access the Administration Server and manage the domain via URL `http://<vm-ip-address>:7001/console/`. By default, the offer configures the Administration Server with a self-signed certificate, you are able to access it with HTTPS `https://<vm-ip-address>:7002/console/`.
    * TLS/SSL termination if you select to configure WebLogic Administration Console on HTTPS (Secure) port, with your own TLS/SSL certificate. The offer sets up the Administration Server with the inputting identity key store and trust key store, and the default secure port is `7002`. The user also can upload the key stores directly or use key stores from Azure Key Vault. You have to configure the Custom DNS to make the HTTPS URL accessible.
    * Coherence Cache.
* Database connectivity
    * Password connections to exiting Azure database for PostgreSQL, Oracle database, Azure SQL and MySQL. You can create data source connectivity to the database using connection string, database user name and password. For MySQL, the offer upgrades the built-in [Oracle WebLogic Server MySQL driver](https://aka.ms/wls-jdbc-drivers) with recent [MySQL Connector Java driver](https://mvnrepository.com/artifact/mysql/mysql-connector-java). The MySQL Connector Java driver is stored in `/u01/domains/preclasspath-libraries/` and loaded by setting the **PRE_CLASSPATH**.
    * Passwordless connections to Azure database for PostgreSQL and MySQL. Passwordless connection requires PostgreSQL or MySQL instance with Azure Managed Identity connection enabled. The offer downloads [Azure Identity Extension Libraries](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-identity-extensions/1.0.0/index.html) to `/u01/domains/azure-libraries/` and loads them to the WLS runtime by setting **PRE_CLASSPATH** and **CLASS_PATH**. The offer also assigns the managed identity that has access to the database to user managed identity of VM.
* Access URLs
    * Access to the Administration Server via HTTP. If you enable traffic to the Administration Server, the HTTP URLs is `http://<vm-ip-address>:7001/console/`.
    * Access to the Administration Server via HTTPS. If you enable traffic to the Administration Server, the HTTPS URL is different for the following scenarios:
        * With TLS/SSL termination enabled and custom DNS enabled, the HTTP URLs is `http://<admin-label>.<dns-zone-name>:7002/console/`. 
        * With on TLS/SSL termination enabled,  the HTTP URLs is `http://<vm-ip-address>:7002/console/`. 
    * Access to cluster and your application via HTTP. If you enable Application Gateway, the HTTP URLs is `http://<app-gateway-hostname>/<app-context-path>/`.
    * Access to cluster and your application via HTTPS:
        * If you enable Application Gateway with signed certificate and custom DNS, the HTTPS URLs is `https://<application-label>.<dns-zone-name>/<app-context-path>/`.
        * If you enable Application Gateway with self-signed certificate, the HTTPS URLs is `https://<app-gateway-hostname>/<app-context-path>/`.

#### Oracle WebLogic Server Dynamic Cluster

### WLS on AKS

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
