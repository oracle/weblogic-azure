#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# Generate parameters with value for deploying db template independently

#read arguments from stdin
read parametersPath adminVMName dbPassword dbName location wlsusername wlspassword repoPath testbranchName

cat <<EOF > ${parametersPath}/parameters-deploy-db.json
{
     "adminVMName":{
        "value": "${adminVMName}"
      },
      "databaseType": {
        "value": "postgresql"
      },
      "dbPassword": {
        "value": "${dbPassword}"
      },
      "dbUser": {
        "value": "weblogic@${dbName}"
      },
      "dsConnectionURL": {
        "value": "jdbc:postgresql://${dbName}.postgres.database.azure.com:5432/postgres?sslmode=require"
      },
      "jdbcDataSourceName": {
        "value": "jdbc/WebLogicCafeDB"
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
        "value": "https://raw.githubusercontent.com/${repoPath}/${testbranchName}/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/"
      },
    }
EOF
