#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Generate parameters with value for deploying delete-node template

parametersPath=$1
adminVMName=$2
location=${3}
wlsusername=${4}
wlspassword=${5}
gitUserName=${6}
testbranchName=${7}
managedServerPrefix=${8}

cat <<EOF > ${parametersPath}
    {
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "deletingManagedServerMachineNames": {
        "value": ["${managedServerPrefix}VM2"]
      },
      "location": {
        "value": "${location}"
      },
      "wlsPassword": {
        "value": "${wlsPassword}"
      },
      "wlsUserName": {
        "value": "${wlsUserName}"
      },
      "_artifactsLocation":{
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-dynamic-cluster/${testbranchName}/deletenode/src/main/"
      }
    }
EOF
