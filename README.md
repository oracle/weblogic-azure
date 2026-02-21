# About WebLogic on Microsoft Azure

As part of a broad-ranging partnership between Oracle and Microsoft, this project offers support for running Oracle WebLogic Server in the Azure Virtual Machines and Azure Kubernetes Service (AKS). The partnership includes joint support for a range of Oracle software running on Azure, including Oracle WebLogic, Oracle Linux, and Oracle DB, as well as interoperability between Oracle Cloud Infrastructure (OCI) and Azure. 

## Integration tests report
* [![CI Validation for Build](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-build.yaml/badge.svg)](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-build.yaml)
* [![CI Validation for AKS](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-aks.yaml/badge.svg)](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-aks.yaml)
* [![CI Validation for VM Admin](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-admin.yaml/badge.svg)](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-admin.yaml)
* [![CI Validation for VM Cluster](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-cluster.yaml/badge.svg)](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-cluster.yaml)
* [![CI Validation for VM Dynamic Cluster](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-dynamic-cluster.yaml/badge.svg)](https://github.com/oracle/weblogic-azure/actions/workflows/it-validation-vm-dynamic-cluster.yaml)

## Installation

The [Azure Marketplace WebLogic Server Offering](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=WebLogic) offers a simplified UI and installation experience over the full power of the Azure Resource Manager (ARM) template.

## Documentation

Please refer to the README for [documentation on WebLogic Server running on an Azure Kubernetes Service](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/)

Please refer to the README for [documentation on WebLogic Server running on an Azure Virtual Machine](https://docs.oracle.com/en/middleware/standalone/weblogic-server/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7)

Please refer to the README for [documentation about how to run the CI/CD](.github/it/README.md).

## Local Build Setup and Requirements

This project utilizes [GitHub Packages](https://github.com/features/packages) for hosting and retrieving some dependencies. To ensure you can smoothly run and build the project in your local environment, specific configuration settings are required.

GitHub Packages requires authentication to download or publish packages. Therefore, you need to configure your Maven `settings.xml` file to authenticate using your GitHub credentials. The primary reason for this is that GitHub Packages does not support anonymous access, even for public packages.

Please follow these steps:

1. Create a Personal Access Token (PAT)
   - Go to [Personal access tokens](https://github.com/settings/tokens).
   - Click on Generate new token.
   - Give your token a descriptive name, set the expiration as needed, and select the scopes (read:packages, write:packages).
   - Click Generate token and make sure to copy the token.
   
2. Configure Maven Settings
    - Locate or create the settings.xml file in your .m2 directory(~/.m2/settings.xml).
    - Add the GitHub Package Registry server configuration with your username and the PAT you just created. It should look something like this:
       ```xml
        <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 
                               https://maven.apache.org/xsd/settings-1.2.0.xsd">
         
       <!-- other settings
       ...
       -->
      
         <servers>
           <server>
             <id>github</id>
             <username>YOUR_GITHUB_USERNAME</username>
             <password>YOUR_PERSONAL_ACCESS_TOKEN</password>
           </server>
         </servers>
      
       <!-- other settings
       ...
       -->
      
        </settings>
       ```


## Deployment Description

### WLS on VMs

#### Oracle WebLogic Server Single Node

The offer provisions the following Azure resources based on Oracle WebLogic Server base images and an Oracle WebLogic Server Enterprise Edition (WLS) without domain configuration.

- The offer includes a choice of operating system, JDK, Oracle WebLogic Server versions.
   - OS: Oracle Linux or Red Hat Enterprise Linux
   - JDK: Oracle JDK 8, or 11
   - WLS version: 12.2.1.4, 14.1.1.0
- Computing resources
   - A VM with the following configurations:
      - Operating system as described in the selected base image.
      - Choice of VM size.
   - An OS disk attached to the VM.
- Network resources
   - A virtual network and a subnet.
   - A network security group.
   - A network interface.
   - A public IP address assigned to the network interface.
- Storage resources
   - An Azure Storage Account to store the VM diagnostics profile.
- Key Software components
   - Oracle WebLogic Server Enterprise Edition. Version as described in the selected base image. The **ORACLE_HOME** is **/u01/app/wls/install/oracle/middleware/oracle_home**.
   - Oracle JDK. The version as described in the selected base image. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}**.
   - In addition to the database drivers that come standard with WLS, the offer includes the most recent supported PostgreSQL JDBC driver and Microsoft SQL JDBC driver. The drivers are stored in **/u01/app/wls/install/oracle/middleware/oracle_home/wlserver/server/lib/**.

#### Oracle WebLogic Server with Admin Server

The offer provisions Oracle WebLogic Server (WLS) with a domain and Administration Server. All supporting Azure resources are automatically provisioned.

- The offer includes a choice of operating system, JDK, Oracle WLS versions.
   - OS: Oracle Linux or Red Hat Enterprise Linux
   - JDK: Oracle JDK 8, or 11
   - WLS version: 12.2.1.4, 14.1.1.0
- Computing resources
   - VM with the followings configuration:
      - A VM to run the Administration Server.
      - Choice of VM size.
   - An OS disk attached to the VM.
- Network resources
   - A virtual network and a subnet. If desired, you can deploy into a pre-existing virtual network.
   - A network security group if creating a new virtual network.
   - Network interface for VM.
   - Public IP address.
- Key software components
   - Oracle WLS Enterprise Edition. Version as described in the selected base image. The **ORACLE_HOME** is **/u01/app/wls/install/oracle/middleware/oracle_home**.
   - Oracle JDK. The version as described in the selected base image. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}**.
   - A WLS domain with the Administration Server up and running. Admin server sign in with the user name and password provided to the offer. The default domain name is **adminDomain**, the domain path is **/u01/domains/adminDomain/**.
- Database connectivity
   - The offer provides database connectivity for PostgreSQL, Oracle database, Azure SQL, MySQL, or an arbitrary JDBC compliant database.
   - Some database options support Azure Passwordless database connection.
- Access URLs
   - See the deployment outputs for access URLs.

#### Oracle WebLogic Server Cluster

The offer provisions Oracle WebLogic Server (WLS) Enterprise Edition with a domain, the Administration Server and a configured cluster. All supporting Azure resources are automatically provisioned.

- The offer includes a choice of operating system, JDK, WLS versions.
   - OS: Oracle Linux or Red Hat Enterprise Linux
   - JDK: Oracle JDK 8, or 11
   - WLS version: 12.2.1.4, 14.1.1.0
- Computing resources
   - VMs with the followings configurations:
      - A VM to run the Administration Server and VMs to run Managed Servers.
      - VMs to run Coherence Cache servers.
      - Choice of VM size.
   - An OS disk attached to the VM.
- Load Balancer
   - If desired, an Azure Application Gateway (agw). The TLS/SSL certificate for the agw can be uploaded, retrieved from a key vault, or self-signed auto-generated.
- Network resources
   - A virtual network and a subnet. If desired, you can deploy into a pre-existing virtual network.
   - A network security group if creating a new virtual network.
   - Network interfaces for VMs.
   - Public IP addresses assigned to the network interfaces
   - Public IP assigned for agw, if desired.
- High Availability
   - An Azure Availability Set for the VMs.
- Key software components
   - WLS Enterprise Edition. Version as described in the selected base image. The **ORACLE_HOME** is **/u01/app/wls/install/oracle/middleware/oracle_home**.
   - Oracle JDK. The version as described in the selected base image. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}***.
   - A WLS domain with the Administration Server up and running. Admin server sign in with the user name and password provided to the offer. The default domain name is **wlsd**, the domain path is **/u01/domains/wlsd/**.
   - A configured cluster with Managed Servers running. The number of managed servers is specified in the UI when deploying the offer.
   - Coherence Cache. If you select to enable Coherence Cache, the offer creates a data tier configured with Managed Coherence cache servers.
- Database connectivity
   - The offer provides database connectivity for PostgreSQL, Oracle database, Azure SQL, MySQL, or an arbitrary JDBC compliant database.
   - Some database options support Azure Passwordless database connection.
- Access URLs
   - See the deployment outputs for access URLs.

#### Oracle WebLogic Server Dynamic Cluster

The offer provisions Oracle WebLogic Server (WLS) Enterprise Edition with a domain, the Administration Server and a dynamic cluster. All supporting Azure resources are automatically provisioned.

- The offer includes a choice of operating system, JDK, WLS versions.
   - OS: Oracle Linux or Red Hat Enterprise Linux
   - JDK: Oracle JDK 8, or 11
   - WLS version: 12.2.1.4, 14.1.1.0
- The offer includes the choice of the following Oracle HTTP Server (OHS) base images
   - OS: Oracle Linux
   - OHS version 12.2.1.4.0
- Computing resources
   - VMs for WLS:
      - A VM to run the Administration Server and VMs to run Managed Servers.
      - VMs to run Coherence Cache servers.
      - Choice of VM size.
      - An OS disk attached to the VM.
   - VM for OHS, if desired:
      - Choice of VM size.
      - An OS disk attached to the VM.
- Load Balancer
   - If desired, an OHS. The TLS/SSL certificate for the OHS can be uploaded, or retrieved from a key vault.
- Network resources
   - A virtual network and a subnet. If desired, you can deploy into a pre-existing virtual network.
   - A network security group if creating a new virtual network.
   - Network interfaces for VMs.
   - Public IP addresses assigned to the network interfaces.
   - A public IP assigned OHS, if desired.
- Storage resources
   - An Azure Storage Account and a file share named **wlsshare**. The mount point is **/mnt/wlsshare**.
   - The storage account is also used to store the diagnostics profile of the VMs.
   - A private endpoint in the same subnet with the VM, which allows the VM to access the file share.
- Key software components for WLS
   - WLS Enterprise Edition. Version as described in the selected base image. The **ORACLE_HOME** is **/u01/app/wls/install/oracle/middleware/oracle_home**.
   - Oracle JDK. The version as described in the selected base image. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}**.
   - A WLS domain with the Administration Server up and running. Admin server sign in with the user name and password provided to the offer. The default domain name is **wlsd**, the domain path is **/u01/domains/wlsd/**.
      - A dynamic cluster with desired number of Managed Servers running. The number of Managed servers is specified by **Initial Dynamic Cluster Size**. The cluster size is specified by **Maximum Dynamic Cluster Size**.
      - Coherence Cache. If you select to enable Coherence Cache, the offer creates a data tier configured with Managed Coherence cache servers.
- Key software components for OHS
   - Version as described in the selected base image. The **ORACLE_HOME** is **/u01/app/ohs/install/oracle/middleware/oracle_home**.
   - Oracle JDK. The version as described in the selected base image. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}**.
   - A domain is configured based on the node manager user name and credentials provided by the user. The default domain name is **ohsStandaloneDomain**, the domain path is **/u01/domains/ohsStandaloneDomain/**.
   - An Oracle HTTP Server Component with default name **ohs_component**.
- Database connectivity
   - The offer provides database connectivity for PostgreSQL, Oracle database, Azure SQL, MySQL, or an arbitrary JDBC compliant database.
   - Some database options support Azure Passwordless database connection.
- Access URLs
   - See the deployment outputs for access URLs.

### WLS on AKS

The offer provisions an Oracle WebLogic Server Enterprise Edition (WLS) and supporting Azure resources. WLS is configured with a domain, the Administration Server and a dynamic cluster set up and running.

- The offer includes the choice of the following WLS container images
   - Images from Oracle Container Registry (OCR) (General or Patched images)
      - OS: Oracle Linux or Red Hat Enterprise Linux
      - JDK: Oracle JDK 8, or 11
      - WLS version: 12.2.1.4, 14.1.1.0
      - You can specify any arbitrary docker image tag that is available from OCR.
   - An image from your own Azure Container Registry.
- Computing resources
   - Azure Kubernetes Service cluster
      - Dynamically created AKS cluster with
         - Choice of Node count.
         - Choice of Node size.
         - Network plugin: Azure CNI.
      - If desired, you can also deploy into a pre-existing AKS cluster.
   - An Azure Container Registry. If desired, you can select a pre-existing Azure Container Registry.
- Network resources
   - A virtual network and a subnet. If desired, you can deploy into a pre-existing virtual network.
   - Public IP addresses assigned to the managed load balancer and Azure Application Gateway, if selected.
- Load Balancer
   - Choice of Azure Application Gateway (agw) or standard load balancer service. With agw, you can upload TLS/SSL certificate, use a certificates stored in a key vault, or allow a self-signed certificate to be generated and installed.
- Storage resources
   - An Azure Storage Account and a file share named weblogic if you select to create Persistent Volume using Azure File share service. The mount point is **/shared**.
- Monitoring resources
   - If desired, Azure Container Insights and workspace.
- Key software components
   - Oracle WebLogic Server Enterprise Edition. The **ORACLE_HOME** is **/u01/app/wls/install/oracle/middleware/oracle_home**.
   - This offer always deploys WLS using the 'Model in image' domain home source type. For more information, see the documentation from Oracle.
   - WebLogic Kubernetes Operator
   - Oracle JDK. The **JAVA_HOME** is **/u01/app/jdk/jdk-${version}**.
   - A WLS domain with the Administration Server up configured based on the provided Administrator user name and credentials. The default domain name is sample-domain1, the domain path is **/u01/domains/sample-domain1/**.
   - A dynamic cluster with Managed Servers running. The number of initial and maximum number of Managed Servers are configurable.
- Database connectivity
   - The offer provides database connectivity for PostgreSQL, Oracle database, Azure SQL, MySQL, or an arbitrary JDBC compliant database.
   - Some database options support Azure Passwordless database connection.
- Access URLs
   - See the deployment outputs for access URLs.

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
