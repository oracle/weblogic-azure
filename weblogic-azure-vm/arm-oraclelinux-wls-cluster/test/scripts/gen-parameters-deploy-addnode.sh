#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to generate test parameters with value for deploying addnode template

#read arguments from stdin
read parametersPath adminPasswordOrKey adminURL adminUsername numberOfExistingNodes skuUrnVersion storageAccountName wlsDomainName location wlsusername wlspassword gitUserName testbranchName managedServerPrefix

# do not include admin node.
numberOfExistingNodes=$((numberOfExistingNodes - 1))

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
      "enableCoherence": {
        "value": true
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
      "vmSizeSelect": {
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/addnode/src/main/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
