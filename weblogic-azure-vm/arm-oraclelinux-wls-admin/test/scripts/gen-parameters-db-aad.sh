#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#read arguments from stdin
read parametersPath repoPath testbranchName

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/"
        },
        "_artifactsLocationSasToken": {
            "value": ""
        },
        "aadsPortNumber": {
            "value": "636"
        },
        "aadsPublicIP": {
            "value": "GEN-UNIQUE"
        },
        "aadsServerHost": {
            "value": "GEN-UNIQUE"
        },
        "adminPasswordOrKey": {
            "value": "GEN-UNIQUE"
        },
        "adminUsername": {
            "value": "GEN-UNIQUE"
        },
        "databaseType": {
            "value": "postgresql"
        },
        "dbPassword": {
            "value": "GEN-UNIQUE"
        },
        "dbUser": {
            "value": "GEN-UNIQUE"
        },
        "dsConnectionURL": {
            "value": "GEN-UNIQUE"
        },
        "enableAAD": {
            "value": true
        },
        "enableDB": {
            "value": true
        },
        "jdbcDataSourceName": {
            "value": "jdbc/postgresql"
        },
        "vmSize": {
            "value": "Standard_B2ms"
        },        
        "wlsLDAPGroupBaseDN": {
            "value": "GEN-UNIQUE"
        },
        "wlsLDAPPrincipal": {
            "value": "GEN-UNIQUE"
        },
        "wlsLDAPPrincipalPassword": {
            "value": "GEN-UNIQUE"
        },
        "wlsLDAPProviderName": {
            "value": "AzureActiveDirectoryProvider"
        },
        "wlsLDAPSSLCertificate": {
            "value": "GEN-UNIQUE"
        },
        "wlsLDAPUserBaseDN": {
            "value": "GEN-UNIQUE"
        },
        "wlsPassword": {
            "value": "GEN-UNIQUE"
        },
        "wlsUserName": {
            "value": "GEN-UNIQUE"
        },
        "enableCustomSSL": {
            "value": false
        }
    }
}
EOF
