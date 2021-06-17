#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying elk template independently

parametersPath=$1
adminVMName=$2
elasticsearchPassword=$3
elasticsearchURI=$4
elasticsearchUserName=$5
location=$6
wlsDomainName=$7
wlsusername=$8
wlspassword=${9}
gitUserName=${10}
testbranchName=${11}
managedServerPrefix=${12}
maxDynamicClusterSize=${13}
dynamicClusterSize=${14}
guidValue=${15}


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
