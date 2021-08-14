# Release Notes

## 2020-Q2

### Features that apply to all offers

* Choice of five different base images.

   | WebLogic Server Version | Oracle JDK Version | Oracle Linux Version |
   |-------------------------|--------------------|----------------------|
   | 12.2.1.3.0              | 8u131              | 7.4                  |
   | 12.2.1.3.0              | 8u131              | 7.3                  |
   | 12.2.1.4.0              | 8u251              | 7.6                  |
   | 14.1.1.0.0              | 8u251              | 7.6                  |
   | 14.1.1.0.0              | 11_07              | 7.6                  |

### arm-oraclelinux-wls

* No additional new features.

### arm-oraclelinux-wls-admin

* Database integration from portal.

* Azure Active Directory Domain Services LDAP integration from portal.

### arm-oraclelinux-wls-cluster

* Database integration from portal.

* Azure Active Directory Domain Services LDAP integration from portal.

* Azure App Gateway integration from portal.

### arm-oraclelinux-wls-dynamic-cluster

* Database integration from portal.

* Azure Active Directory Domain Services (Azure AD DS) LDAP integration from portal.

### Known Issues

* Azure AD DS integration does not work for WebLogic Server 14.

* For cluster offers, the maximum recommended number of VMs per deployment is 20.  This is due to the default limits for storage accounts.  For more information see [Azure subscription and service limits, quotas, and constraints](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#storage-limits).
   * Customers may experience Azure IaaS VM performance issues if too many OS and/or data disk VHD files are stored in each Storage Account
   * Storage Accounts are limited to **20,000 IOPS**
   * We expect each disk to experience up to **500 IOPS**
   * We can determine approximately how many OS and data disk VHD files, as a maximum number, should reside in each storage account
   * 20,000 IOPS / 500 per-disk IOPS = 40 VHDs max per Storage Account
   * Each VM uses two VHDs, therefore 20 VMs.

### Source Tags and Marketplace Bundle Versions

| Repository Name | GitHub Tag Link | Corresponding Marketplace Bundle Version |
|-----------------|-----------------|------------------------------------------|
| arm-oracle-linux-wls | [v1.0.0](https://github.com/wls-eng/arm-oraclelinux-wls/releases/tag/v1.0.0) | 1.0.17 |
| arm-oraclelinux-wls-admin | [v1.0.0](https://github.com/wls-eng/arm-oraclelinux-wls-admin/releases/tag/v1.0.0) | 1.0.21 |
| arm-oraclelinux-wls-cluster | [v1.0.0](https://github.com/wls-eng/arm-oraclelinux-wls-cluster/releases/tag/v1.0.0) | 1.0.290000 |
| arm-oraclelinux-wls-dynamic-cluster | [v1.0.0](https://github.com/wls-eng/arm-oraclelinux-wls-dynamic-cluster/releases/tag/v1.0.0) | 1.0.19 |

-----------------------------------------------------------------

## 2019-Q4

### Features that apply to all offers

* Network Security Group pre-created with correct ports for WebLogic Server.

### arm-oraclelinux-wls

* Single node with no domain pre-created.

### arm-oraclelinux-wls-admin

* Single node with domain pre-created with admin server running.

* Database integration via script execution on admin server.

### arm-oraclelinux-wls-cluster

* Configured cluster with arbitrary number of nodes.

* Database integration via script execution on admin server.

### arm-oraclelinux-wls-dynamic-cluster

* Dynamic cluster with arbitrary number of nodes.

* Database integration via script execution on admin server.

### Source Tags and Marketplace Bundle Versions

| Repository Name | GitHub Tag Link | Corresponding Marketplace Bundle Version |
|-----------------|-----------------|------------------------------------------|
| arm-oracle-linux-wls | [v0.6.0](https://github.com/wls-eng/arm-oraclelinux-wls/releases/tag/v0.6.0) | 1.0.16 |
| arm-oraclelinux-wls-admin | [v0.6.0](https://github.com/wls-eng/arm-oraclelinux-wls-admin/releases/tag/v0.6.0) | 1.0.14 |
| arm-oraclelinux-wls-cluster | [v0.6.0](https://github.com/wls-eng/arm-oraclelinux-wls-cluster/releases/tag/v0.6.0) | 1.0.17 |
| arm-oraclelinux-wls-dynamic-cluster | [v0.6.0](https://github.com/wls-eng/arm-oraclelinux-wls-dynamic-cluster/releases/tag/v0.6.0) | 1.0.11 |

