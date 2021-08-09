#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# Generate parameters with value for deploying delete-node template.

#read arguments from stdin
read parametersPath adminVMName location wlsusername wlspassword gitUserName testbranchName managedServerPrefix

cat <<EOF > ${parametersPath}
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "deletingManagedServerNames": {
        "value": ["${managedServerPrefix}2","${managedServerPrefix}Storage2"]
      },
      "deletingManagedServerMachineNames": {
        "value": ["${managedServerPrefix}VM2","${managedServerPrefix}StorageVM2"]
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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/deletenode/src/main/"
      }
    }
EOF
