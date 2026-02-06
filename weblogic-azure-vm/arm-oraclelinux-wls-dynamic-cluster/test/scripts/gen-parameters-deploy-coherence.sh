#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying coherence template independently

read parametersPath adminVMName adminPasswordOrKey skuUrnVersion location storageAccountName wlsDomainName wlsusername wlspassword repoPath testbranchName managedServerPrefix

cat <<EOF > ${parametersPath}
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "adminPasswordOrKey": {
        "value": "${adminPasswordOrKey}"
      },
      "enableCoherenceWebLocalStorage": {
        "value": true
      },
      "numberOfCoherenceCacheInstances": {
        "value": 1
      },
      "skuUrnVersion": {
        "value": "${skuUrnVersion}"
      },
      "location": {
        "value": "${location}"
      },
      "storageAccountName": {
        "value": "${storageAccountName}"
      },
      "vmSizeSelectForCoherence": {
         "value": "Standard_D2s_v3"
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
        "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
