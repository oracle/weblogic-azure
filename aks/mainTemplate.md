<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

# Create Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration

This page documents how to create Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration using Azure CLI.

## Introduction

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.


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
