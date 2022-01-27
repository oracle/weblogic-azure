# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to configure datasource at WebLogic cluster domain.

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./configDatasource.sh <<< \"<dataSourceConfigArgumentsFromStdIn>\""
}

function validateInput()
{

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
        echo _stderr "Please provide Azure SQL Database URL in the format 'jdbc:oracle:thin:@<db host name>:<db port>/<database name>'"
        exit 1
   fi

   if [ -z "$dsUser" ];
   then
       echo _stderr "Please provide Azure SQL Database user name"
       exit 1
   fi

   if [ -z "$dsPassword" ];
   then
       echo _stderr "Please provide Azure SQL Database password"
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
  cmo.setDriverName('com.microsoft.sqlserver.jdbc.SQLServerDriver')
  cmo.setPassword('$dsPassword')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCConnectionPoolParams/$jdbcDataSourceName')
  cmo.setTestTableName('SQL ISVALID\r\n\r\n\r\n\r\n')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDriverParams/$jdbcDataSourceName/Properties/$jdbcDataSourceName')
  cmo.createProperty('user')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDriverParams/$jdbcDataSourceName/Properties/$jdbcDataSourceName/Properties/user')
  cmo.setValue('$dsUser')
  cd('/JDBCSystemResources/$jdbcDataSourceName/JDBCResource/$jdbcDataSourceName/JDBCDataSourceParams/$jdbcDataSourceName')
  cmo.setGlobalTransactionsProtocol('${dbGlobalTranPro}')
  cd('/JDBCSystemResources/$jdbcDataSourceName')
  set('Targets',jarray.array([ObjectName('com.bea:Name=$wlsClusterName,Type=Cluster')], ObjectName))
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

#main

#read arguments from stdin
read oracleHome wlsAdminHost wlsAdminPort wlsUserName wlsPassword jdbcDataSourceName dsConnectionURL dsUser dsPassword dbGlobalTranPro wlsClusterName

if [ -z "$wlsClusterName" ];
then
   wlsClusterName="cluster1"
fi

wlsAdminURL=$wlsAdminHost:$wlsAdminPort
hostName=`hostname`

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