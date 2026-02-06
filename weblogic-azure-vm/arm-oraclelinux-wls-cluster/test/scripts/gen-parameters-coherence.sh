#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to generate test parameters for coherence testing.

#read arguments from stdin
read parametersPath repoPath testbranchName

cat <<EOF >${parametersPath}
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
        "adminPasswordOrKey": {
            "value": "GEN-UNIQUE"
        },
        "adminUsername": {
            "value": "GEN-UNIQUE"
        },
        "adminVMNamePrefix": {
            "value": "GEN-UNIQUE"
        },
        "enableCoherence": {
            "value": true
        },
        "vmSize": {
            "value": "Standard_D2s_v3"
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
