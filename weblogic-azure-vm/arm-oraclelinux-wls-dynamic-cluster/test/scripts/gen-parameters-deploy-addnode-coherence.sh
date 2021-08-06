#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying addnode template

read parametersPath adminPasswordOrKey adminVMName adminUsername numberOfExistingCacheNodes skuUrnVersion storageAccountName wlsDomainName location wlsusername wlspassword gitUserName testbranchName managedServerPrefix

cat <<EOF > ${parametersPath}
{
     "adminPasswordOrKey":{
        "value": "${adminPasswordOrKey}"
      },
      "adminVMName": {
        "value": "${adminVMName}"
      },
      "adminUsername": {
        "value": "${adminUsername}"
      },
      "numberOfExistingCacheNodes": {
        "value": ${numberOfExistingCacheNodes}
      },
      "numberOfNewCacheNodes": {
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
      "vmSizeSelectForCoherence": {
            "value": "Standard_D2as_v4"
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-dynamic-cluster/${testbranchName}/addnode-coherence/src/main/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
