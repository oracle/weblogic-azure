#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to generate test parameters for Appgateway testing.

#read arguments from stdin
read parametersPath repoPath testbranchName adminVMName appGatewaySSLCertificateData appGatewaySSLCertificatePassword numberOfInstances location wlsPassword wlsUserName wlsDomainName managedServerPrefix

cat <<EOF > ${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/"
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
