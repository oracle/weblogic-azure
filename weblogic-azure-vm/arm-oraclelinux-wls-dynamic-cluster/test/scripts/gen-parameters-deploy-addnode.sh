#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying addnode template

read parametersPath adminPasswordOrKey adminURL adminUsername numberOfExistingNodes skuUrnVersion storageAccountName wlsDomainName location wlsusername wlspassword repoPath testbranchName managedServerPrefix dynamicClusterSize maxDynamicClusterSize

cat <<EOF > ${parametersPath}
{
     "adminPasswordOrKey":{
        "value": "${adminPasswordOrKey}"
      },
      "adminURL": {
        "value": "${adminURL}"
      },
      "adminUsername": {
        "value": "${adminUsername}"
      },
      "numberOfExistingNodes": {
        "value": ${numberOfExistingNodes}
      },
      "numberOfNewNodes": {
        "value": 1
      },
      "location": {
        "value": "${location}"
      },
      "skuUrnVersion": {
        "value": "${skuUrnVersion}"
      },
      "storageAccountName": {
        "value": "${storageAccountName}"
      },
      "vmSize": {
            "value": "Standard_B2ms"
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
      "_artifactsLocation":{
        "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/addnode/src/main/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      },
      "dynamicClusterSize": {
        "value": ${dynamicClusterSize}
      },
      "maxDynamicClusterSize": {
        "value": ${maxDynamicClusterSize}
      }
}
EOF
