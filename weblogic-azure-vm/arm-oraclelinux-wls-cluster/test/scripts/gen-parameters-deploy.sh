#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to generate general test parameters for testing.

#read arguments from stdin
read parametersPath repoPath testbranchName location adminPasswordOrKey wlsUserName wlsDomainName skuUrnVersion dbName dbServerName dbPassword dbUser wlsPassword

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/"
        },
        "_artifactsLocationSasToken": {
            "value": ""
        },
        "location": {
            "value": "${location}"
        },
        "adminPasswordOrKey": {
            "value": "${adminPasswordOrKey}"
        },
        "adminUsername": {
            "value": "weblogic"
        },
        "appGatewayCertificateOption": {
            "value": "generateCert"
        },
        "authenticationType": {
            "value": "password"
        },
        "enableDB": {
            "value": true
        },
        "databaseType": {
            "value": "postgresql"
        },
        "dsConnectionURL": {
            "value": "jdbc:postgresql://${dbServerName}.postgres.database.azure.com:5432/${dbName}?sslmode=require"
        },
        "dbGlobalTranPro": {
            "value": "EmulateTwoPhaseCommit"
        },
        "dbPassword": {
            "value": "${dbPassword}"
        },
        "dbUser": {
            "value": "${dbUser}"
        },
        "enableAppGateway": {
            "value": true
        },
        "enableCoherence": {
            "value": true
        },
        "enableCoherenceWebLocalStorage": {
            "value": true
        },
        "enableCookieBasedAffinity": {
            "value": true
        },
        "enableDNSConfiguration": {
            "value": false
        },
        "enablePswlessConnection": {
            "value": false
        },
        "hasDNSZones": {
            "value": false
        },
        "jdbcDataSourceName": {
            "value": "jdbc/WebLogicCafeDB"
        },
        "numberOfCoherenceCacheInstances": {
            "value": 1
        },
        "numberOfInstances": {
            "value": 4
        },
        "skuUrnVersion": {
            "value": "${skuUrnVersion}"
        },
        "vmSize": {
            "value": "Standard_B1ms"
        },
        "vmSizeSelectForCoherence": {
            "value": "Standard_B1ms"
        },
        "wlsDomainName": {
            "value": "${wlsDomainName}"
        },
        "wlsPassword": {
            "value": "${wlsPassword}"
        },
        "wlsUserName": {
            "value": "${wlsUserName}"
        },
        "enableCustomSSL": {
            "value": false
        },
        "tagsByResource": {
            "value": {
            "Microsoft.Network/applicationGateways": {
                "Owner": "test"
            },
            "Microsoft.Compute/availabilitySets": {
                "Owner": "test"
            },
            "Microsoft.Resources/deploymentScripts": {
                "Owner": "test"
            },
            "Microsoft.Network/dnszones": {
                "Owner": "test"
            },
            "Microsoft.KeyVault/vaults": {
                "Owner": "test"
            },
            "Microsoft.ManagedIdentity/userAssignedIdentities": {
                "Owner": "test"
            },
            "Microsoft resources deployment": {
                "Owner": "test"
            },
            "Microsoft.Network/networkInterfaces": {
                "Owner": "test"
            },
            "Microsoft.Network/networkSecurityGroups": {
                "Owner": "test"
            },
            "Microsoft.Network/privateEndpoints": {
                "Owner": "test"
            },
            "Microsoft.Network/publicIPAddresses": {
                "Owner": "test"
            },
            "Microsoft.Storage/storageAccounts": {
                "Owner": "test"
            },
            "Microsoft.Compute/virtualMachines": {
                "Owner": "test"
            },
            "Virtual machine extension": {
                "Owner": "test"
            },
            "Microsoft.Network/virtualNetworks": {
                "Owner": "test"
            }
        }
    }
}
}
EOF
