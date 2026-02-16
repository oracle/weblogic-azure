#!/bin/bash
# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

gitUserName=$1
testbranchName=$2
appPackageUrls=$3
dbPassword=$4
dbUser=$5
dsConnectionURL=$6
location=$7
ocrSSOPSW=$8
ocrSSOUser=$9
wdtRuntimePassword=${10}
wlsPassword=${11}
wlsUserName=${12}
vmSize=${13}
parametersPath=${14}


cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    // This file is used by CI/CD workflows. It allows the workflows to provide parameters when invoking the offer from the command line.
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${gitUserName}/weblogic-azure/${testbranchName}/weblogic-azure-aks/src/main/arm/"
        },
        "aksAgentPoolNodeCount": {
            "value": 3
        },
        "vmSize": {
            "value": "${vmSize}"
        },
        "appGatewayCertificateOption": {
            "value": "generateCert"
        },
        "appgwForAdminServer": {
            "value": true
        },
        "appgwForRemoteConsole": {
            "value": true
        },
        "appPackageUrls": {
            "value": [
                "${appPackageUrls}"
            ]
        },
        "appReplicas": {
            "value": 2
        },
        "createACR": {
            "value": true
        },
        "createAKSCluster": {
            "value": true
        },
        "createDNSZone": {
            "value": true
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
        "databaseType": {
            "value": "postgresql"
        },
        "dsConnectionURL": {
            "value": "${dsConnectionURL}"
        },
        "enableAppGWIngress": {
            "value": true
        },
        "enableAzureMonitoring": {
            "value": false
        },
        "enableAzureFileShare": {
            "value": true
        },
        "enableCookieBasedAffinity": {
            "value": true
        },
        "enableCustomSSL": {
            "value": false
        },
        "enableDB": {
            "value": true
        },
        "enableDNSConfiguration": {
            "value": false
        },
        "jdbcDataSourceName": {
            "value": "jdbc/CargoTrackerDB"
        },
        "location": {
            "value": "${location}"
        },
        "ocrSSOPSW": {
            "value": "${ocrSSOPSW}"
        },
        "ocrSSOUser": {
            "value": "${ocrSSOUser}"
        },
        "useInternalLB": {
            "value": false
        },
        "useOracleImage": {
            "value": true
        },
        "wdtRuntimePassword": {
            "value": "${wdtRuntimePassword}"
        },
        "wlsImageTag": {
            "value": "14.1.2.0-generic-jdk17-ol9"
        },
        "wlsPassword": {
            "value": "${wlsPassword}"
        },
        "wlsUserName": {
            "value": "${wlsUserName}"
        }
    }
}
EOF
