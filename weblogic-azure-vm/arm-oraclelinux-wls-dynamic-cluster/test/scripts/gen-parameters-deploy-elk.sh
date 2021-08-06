#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying elk template independently

read parametersPath adminVMName elasticsearchPassword elasticsearchURI elasticsearchUserName location wlsDomainName wlsusername wlspassword gitUserName testbranchName managedServerPrefix maxDynamicClusterSize dynamicClusterSize guidValue


cat <<EOF > ${parametersPath}
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "elasticsearchPassword": {
        "value": "${elasticsearchPassword}"
      },
      "elasticsearchEndpoint": {
        "value": "${elasticsearchURI}"
      },
      "elasticsearchUserName": {
        "value": "${elasticsearchUserName}"
      },
      "guidValue": {
        "value": "${guidValue}"
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
      "_artifactsLocation":{
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-dynamic-cluster/${testbranchName}/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      },
      "maxDynamicClusterSize": {
        "value": ${maxDynamicClusterSize}
      },
      "numberOfManagedApplicationInstances": {
        "value": ${dynamicClusterSize}
      },
      "guidValue": {
        "value": "${guidValue}"
      }
    }
EOF
