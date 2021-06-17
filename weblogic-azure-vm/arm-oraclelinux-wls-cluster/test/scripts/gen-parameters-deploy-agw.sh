#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to generate test parameters for Appgateway testing.

parametersPath=$1
githubUserName=$2
testbranchName=$3
adminVMName=$4
appGatewaySSLCertificateData=$5
appGatewaySSLCertificatePassword=$6
numberOfInstances=$7
location=$8
wlsPassword=$9
wlsUserName=${10}
wlsDomainName=${11}
managedServerPrefix=${12}

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${githubUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/arm-oraclelinux-wls-cluster/src/main/arm/"
        },
        "adminVMName": {
            "value": "${adminVMName}"
        },
        "appGatewaySSLCertificateData": {
            "value": "${appGatewaySSLCertificateData}"
        },
        "appGatewaySSLCertificatePassword": {
            "value": "${appGatewaySSLCertificatePassword}"
        },
        "numberOfInstances": {
            "value": ${numberOfInstances}
        },
        "location": {
            "value": "${location}"
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
        "managedServerPrefix": {
            "value": "${managedServerPrefix}"
        }
    }
}
EOF
