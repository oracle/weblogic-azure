#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deployment
read parametersPath location adminPasswordOrKey wlsdomainname wlsusername wlspassword managedserverprefix maxDynamicClusterSize dynamicClusterSize adminvmname skuUrnVersion testbranchName repoPath 

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
      "value": "Standard_D2as_v4"
    },
    "location": {
      "value": "$location"
    },
    "skuUrnVersion": {
      "value": "$skuUrnVersion"
    },
    "_artifactsLocation": {

      "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
    }
  }
}
EOF

