#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#

read parametersPath repoPath testbranchName keyVaultName keyVaultResourceGroup keyVaultSSLCertDataSecretName keyVaultSSLCertPasswordSecretName

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
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
        "enableAAD": {
            "value": true
        },
        "enableDB": {
            "value": false
        },
        "keyVaultName": {
            "value": "${keyVaultName}"
        },
        "keyVaultResourceGroup": {
            "value": "${keyVaultResourceGroup}"
        },
        "keyVaultSSLCertDataSecretName": {
            "value": "${keyVaultSSLCertDataSecretName}"
        },
        "keyVaultSSLCertPasswordSecretName": {
            "value": "${keyVaultSSLCertPasswordSecretName}"
        },
        "maxDynamicClusterSize": {
            "value": 4
        },
        "dynamicClusterSize": {
            "value": 2
        },
        "vmSizeSelect": {
            "value": "Standard_D2as_v4"
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
        }
    }
}
EOF
