#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# Generate parameters with value for deploying elk template independently.

parametersPath=$1
adminVMName=$2
elasticsearchPassword=$3
elasticsearchURI=$4
elasticsearchUserName=$5
location=$6
numberOfInstances=$7
wlsDomainName=$8
wlsusername=$9
wlspassword=${10}
gitUserName=${11}
testbranchName=${12}
managedServerPrefix=${13}
guidValue=${14}

numberOfInstances=$((numberOfInstances-1))

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
      "numberOfManagedApplicationInstances": {
        "value": ${numberOfInstances}
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/arm-oraclelinux-wls-cluster/src/main/arm/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
