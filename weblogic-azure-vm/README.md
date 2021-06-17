# About WebLogic on Microsoft Azure Virtual Machine

As part of a broad-ranging partnership between Oracle and Microsoft, this project offers support for running Oracle WebLogic Server in Azure Virtual Machine. The partnership includes joint support for a range of Oracle software running on Azure, including Oracle WebLogic, Oracle Linux, and Oracle DB, as well as interoperability between Oracle Cloud Infrastructure (OCI) and Azure. 

This is the main/root git repository for the Azure Resource Management (ARM) templates and other scripts used for the implementation of WebLogic Server on Microsoft Azure Virtual Machine.

## Installation

The [Azure Marketplace WebLogic Server Offering](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=WebLogic) offers a simplified UI and installation experience over the full power of the ARM template.

The following are few single/multinode deployment offers that are available in the Azure Marketplace:

- Bootstrap an Oracle Linux VM with pre-installed WebLogic Server (without Administration Server)
- Oracle WebLogic Server with Administration Server
- Oracle WebLogic Server N-Node cluster
- Oracle WebLogic Server N-Node dynamic cluster

---

![WebLogic Server Azure Marketplace UI Flow](weblogic-azure-vm/arm-oraclelinux-wls/images/wls-on-azure.gif)

---

In this GitHub project under weblogic-azure-vm you can find the Azure Resource Manager (ARM) templates for each of these Azure Marketplace WebLogic Server Offerings.  These ARM templates can be used to deploy the offering directly from the Azure CLI or Azure Powershell.

The following are the corresponding directories:

- [https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls](https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls)

- [https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-admin](https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-admin)

- [https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-cluster](https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-cluster)

- [https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster](https://github.com/oracle/weblogic-azure/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster)

## Documentation

Please refer to the documentation [Oracle WebLogic Server Azure Applications](https://docs.oracle.com/en/middleware/standalone/weblogic-server/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7)

## Examples

To get details of how to run Oracle WebLogic Server on Azure Virtual Machines refer to the blog [WebLogic on Azure Virtual Machines Major Release Now Available](https://blogs.oracle.com/weblogicserver/weblogic-on-azure-virtual-machines-major-release-now-available).

## Issues

Issue related to Oracle WebLogic Server on Microsoft Azure implementation are tracked ain the [Issues tab](https://github.com/oracle/weblogic-azure/issues) of the GitHub project.

## Workflow Tracker

This section tracks GitHub Actions configured for each offer repo, 'Build and Test' and 'New Tag' are two different workflows.
|  Offer Repo  |   Build and Test | New Tag |
|--- |--- |--- |
| [Single Node] | [Build and Test]| [New Tag]|
| [Admin]  | [Build and Test] | [New Tag] |
| [Configured Cluster]  | [Build and Test]svg) | [New Tag]) |
| [Dynamic Cluster] |  [Build and Test] | [New Tag] |

## Pull Requests

This section tracks GitHub pull requests.
https://github.com/oracle/weblogic-azure/pulls

## License

Copyright (c) 2021 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.
