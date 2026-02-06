#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deployment
read parametersPath location adminPasswordOrKey wlsdomainname wlsusername wlspassword managedserverprefix maxDynamicClusterSize dynamicClusterSize skuUrnVersion testbranchName repoPath dbName dbServerName dbPassword dbUser uploadedKeyStoreData

cat <<EOF >${parametersPath}
{

  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminUsername": {
      "value": "weblogic"
    },
    "adminPasswordOrKey": {
      "value": "$adminPasswordOrKey"
    },
    "dnsLabelPrefix": {
      "value": "wls"
    },
    "wlsDomainName": {
      "value": "$wlsdomainname"
    },
    "wlsUserName": {
      "value": "$wlsusername"
    },
    "wlsPassword": {
      "value": "$wlspassword"
    },
    "managedServerPrefix":{
      "value": "$managedserverprefix"
    },
    "maxDynamicClusterSize": {
      "value": $maxDynamicClusterSize
    },
    "dynamicClusterSize": {
      "value": $dynamicClusterSize
    },
    "vmSize": {
      "value": "Standard_D2s_v3"
    },
    "location": {
      "value": "$location"
    },
    "skuUrnVersion": {
      "value": "$skuUrnVersion"
    },
    "_artifactsLocation": {

      "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
    },
    "addressPrefixes": {
        "value": [
            "172.16.8.0/28"
        ]
    },
    "subnetPrefix": {
        "value": "172.16.8.0/28"
    },
    "enableCoherence": {
        "value": true
    },
    "enableCoherenceWebLocalStorage": {
        "value": true
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
    "jdbcDataSourceName": {
        "value": "jdbc/WebLogicCafeDB"
    },
    "enableOHS": {
      "value": true
    },
    "ohsNMUser": {
      "value": "weblogic"
    },
    "ohsNMPassword": {
      "value": "$wlspassword"
    },
    "oracleVaultPswd": {
      "value": "$wlspassword"
    },
    "uploadedKeyStoreData": {
      "value": "${uploadedKeyStoreData}"
    },
    "uploadedKeyStorePassword": {
      "value": "$wlspassword"
    },
    "uploadedKeyStoreType": {
      "value": "JKS"
    }
  }
}
EOF

