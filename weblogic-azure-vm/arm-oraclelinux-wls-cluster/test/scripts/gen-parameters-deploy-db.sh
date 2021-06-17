#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# Generate parameters with value for deploying db template independently

parametersPath=$1
adminVMName=$2
dbPassword=$3
dbName=$4
location=$5
wlsusername=$6
wlspassword=$7
gitUserName=$8
testbranchName=$9

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
        "value": "https://raw.githubusercontent.com/${gitUserName}/arm-oraclelinux-wls-cluster/${testbranchName}/arm-oraclelinux-wls-cluster/src/main/arm/"
      },
    }
EOF
