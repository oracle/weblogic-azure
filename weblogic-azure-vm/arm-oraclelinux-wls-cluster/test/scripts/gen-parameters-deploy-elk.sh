#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# Generate parameters with value for deploying elk template independently.

#read arguments from stdin
read parametersPath adminVMName elasticsearchPassword elasticsearchURI elasticsearchUserName location numberOfInstances wlsDomainName wlsusername wlspassword repoPath testbranchName managedServerPrefix guidValue

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
        "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/"
      },
      "managedServerPrefix": {
        "value": "${managedServerPrefix}"
      }
    }
EOF
