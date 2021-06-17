#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deployment
parametersPath=$1
location=$2
adminPasswordOrKey=$3
wlsdomainname=$4
wlsusername=$5
wlspassword=$6
managedserverprefix=$7
maxDynamicClusterSize=$8
dynamicClusterSize=$9
adminvmname=${10}
skuUrnVersion=${11}
testbranchName=${12}
gitUserName=${13}

cat <<EOF >${parametersPath}
{

  "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
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
    "adminVMName": {
      "value": "$adminvmname"
    },
    "vmSizeSelect": {
      "value": "Standard_A3"
    },
    "location": {
      "value": "$location"
    },
    "skuUrnVersion": {
      "value": "$skuUrnVersion"
    },
    "_artifactsLocation": {

      "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-dynamic-cluster/${testbranchName}/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
    }
  }
}
EOF

