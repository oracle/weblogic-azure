#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description
#  This script configures datasource on WebLogic Server Domain for PostgreSQL database.

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./configDatasource.sh <<< \"<wlsDataSourceSetupArgsFromStdIn>\""
}

function validateInput()
{
   # parse base64 string
   wlsPassword=$(echo "${wlsPassword}" | base64 -d)
   jdbcDataSourceName=$(echo "${jdbcDataSourceName}" | base64 -d)
   dsConnectionURL=$(echo "${dsConnectionURL}" | base64 -d)
   dsPassword=$(echo "${dsPassword}" | base64 -d)

   if [ -z "$oracleHome" ];
   then
       echo _stderr "Please provide oracleHome"
       exit 1
   fi

   if [ -z "$wlsAdminHost" ];
   then
       echo _stderr "Please provide WeblogicServer hostname"
       exit 1
   fi

   if [ -z "$wlsAdminPort" ];
   then
       echo _stderr "Please provide Weblogic admin port"
       exit 1
   fi

   if [ -z "$wlsUserName" ];
   then
       echo _stderr "Please provide Weblogic username"
       exit 1
   fi

   if [ -z "$wlsPassword" ];
   then
       echo _stderr "Please provide Weblogic password"
       exit 1
   fi

   if [ -z "$jdbcDataSourceName" ];
   then
       echo _stderr "Please provide JDBC datasource name to be configured"
       exit 1
   fi

   if [ -z "$dsConnectionURL" ];
   then
        echo _stderr "Please provide PostgreSQL Database URL in the format 'jdbc:oracle:thin:@<db host name>:<db port>/<database name>'"
        exit 1
   else
        echo  "dsConnectionURL=$dsConnectionURL"
   fi

   if [ -z "$dsUser" ];
   then
       echo _stderr "Please provide PostgreSQL Database user name"
       exit 1
   fi

   if [ -z "$dsPassword" ];
   then
       echo _stderr "Please provide PostgreSQL Database password"
       exit 1
   fi

   if [ -z "$dbGlobalTranPro" ];
   then
       echo _stderr "Please provide Global transactions protocol"
       exit 1
   fi

   if [ -z "$wlsClusterName" ];
   then
       echo _stderr "Please provide Weblogic target cluster name"
       exit 1
   fi

   if [ -z "${enablePswlessConnection}" ];
   then
       echo _stderr "Please provide enablePswlessConnection to identity if enabling passwordless connection."
       exit 1
   fi

   # reset password
   if [[ "${enablePswlessConnection,,}" == "true" ]]; then
       dsPassword=""
   fi
}

function createJDBCSource_model()
{
echo "Creating JDBC data source with name $jdbcDataSourceName"
cat <<EOF >${scriptPath}/create_datasource.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
edit("$hostName")
startEdit()
cd('/')
try:
  cmo.createJDBCSystemResource('$jdbcDataSourceName')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName')
  cmo.setName('$jdbcDataSourceName')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDataSourceParams/$jdbcDataSourceName')
  set('JNDINames',jarray.array([String('$jdbcDataSourceName')], String))
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName')
  cmo.setDatasourceType('GENERIC')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDriverParams/$jdbcDataSourceName')
  cmo.setUrl('$dsConnectionURL')
  cmo.setDriverName('org.postgresql.Driver')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCConnectionPoolParams/$jdbcDataSourceName')
  cmo.setTestTableName('SQL ISVALID\r\n\r\n\r\n\r\n')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDriverParams/$jdbcDataSourceName/Properties/$jdbcDataSourceName')
  cmo.createProperty('user')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDriverParams/$jdbcDataSourceName/Properties/$jdbcDataSourceName/Properties/user')
  cmo.setValue('$dsUser')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDataSourceParams/$jdbcDataSourceName')
  cmo.setGlobalTransactionsProtocol('${dbGlobalTranPro}')
  cd('/JDBCSystemResources/$jdbcDataSourceName')
  set('Targets',jarray.array([ObjectName('com.bea:Name=admin,Type=Server')], ObjectName))
  save()
  resolve()
  activate()
except Exception, e:
  e.printStackTrace()
  dumpStack()
  undo('true',defaultAnswer='y')
  cancelEdit('y')
  destroyEditSession("$hostName",force = true)
  raise("$jdbcDataSourceName configuration failed")
destroyEditSession("$hostName",force = true)
disconnect()
EOF
}

function createTempFolder()
{
    scriptPath="/u01/tmp"
    sudo rm -f -r ${scriptPath}
    sudo mkdir ${scriptPath}
    sudo rm -rf $scriptPath/*
}

# store arguments in a special array 
args=("$@") 
# get number of elements 
ELEMENTS=${#args[@]} 
 
#main

#read arguments from stdin
read oracleHome wlsAdminHost wlsAdminPort wlsUserName wlsPassword jdbcDataSourceName dsConnectionURL dsUser dsPassword dbGlobalTranPro enablePswlessConnection wlsClusterName

wlsAdminURL=$wlsAdminHost:$wlsAdminPort
hostName=`hostname`

if [ -z "$wlsClusterName" ];
then
   wlsClusterName="cluster1"
fi

createTempFolder
validateInput
createJDBCSource_model

sudo chown -R oracle:oracle ${scriptPath}
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${scriptPath}/create_datasource.py"

errorCode=$?
if [ $errorCode -eq 1 ]
then 
    echo "Exception occurs during DB configuration, please check."
    exit 1
fi

echo "Cleaning up temporary files..."
rm -f -r ${scriptPath}

