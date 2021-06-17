#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#Generate parameters with value for deploying elk template independently

parametersPath=$1
adminVMName=$2
elasticsearchPassword=$3
elasticsearchURI=$4
elasticsearchUserName=$5
location=$6
wlsDomainName=$7
wlsusername=$8
wlspassword=$9
gitUserName=${10}
testbranchName=${11}
guidValue=${12}

cat <<EOF > ${parametersPath}
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "elasticsearchEndpoint": {
        "value": "${elasticsearchURI}"
      },
      "elasticsearchPassword": {
        "value": "${elasticsearchPassword}"
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-admin/${testbranchName}/src/main/arm/"
      }
    }
EOF
