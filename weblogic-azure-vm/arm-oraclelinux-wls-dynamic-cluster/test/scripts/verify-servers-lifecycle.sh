#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#

managedServers="#managedServers#"
# Shutdown the server and verify whether it is in SHUTDOWN state
# Restart the managed server
for managedServer in $managedServers
do
  echo "Shut down managed server : $managedServer"
  curl --user #wlsUserName#:#wlspassword# -X POST -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://#adminVMName#:7001/management/weblogic/latest/domainRuntime/serverRuntimes/$managedServer/shutdown" --data '{}'
  sleep 1m
  curl --user #wlsUserName#:#wlspassword# -X GET -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://#adminVMName#:7001/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer" | grep "\"state\": \"SHUTDOWN\""
  if [ $? != 0 ]; then
    echo "$managedServer managed server is not in SHUTDOWN state"
    exit 1
  fi   
  echo "$managedServer managed server is in SHUTDOWN state and starting " 
  curl --user #wlsUserName#:#wlspassword# -X POST -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://#adminVMName#:7001/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer/start" --data '{}'
  sleep 30s
done  

echo "Wait for few minutes for managed server to restart"
sleep 3m
# Check whether managed server is in RUNNING state
for managedServer in $managedServers
do
  echo "Verifying managed server : $managedServer"
  isSuccess=false
  maxAttempt=10
  attempt=1
  while [ $attempt -le $maxAttempt ]
  do
     curl --user #wlsUserName#:#wlspassword# -X GET -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://#adminVMName#:7001/management/weblogic/latest/domainRuntime/serverRuntimes/$managedServer" | grep "\"state\": \"RUNNING\""
     if [ $? == 0 ]; then
       isSuccess=true
       break
     fi
     attempt=`expr $attempt + 1 `
     sleep 30s
  done
  if [[ $isSuccess == "false" ]]; then
    echo "$managedServer managed server is not in RUNNING state"
    exit 1
  else
    echo "$managedServer managed server is in RUNNING state"
  fi
done
exit 0

