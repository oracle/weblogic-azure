#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to test WebLogic admin, console and managed servers access.

# Verifying admin server is accessible
adminPublicIP="$1"
adminPort=$2
wlsUserName=$3
wlspassword=$4
managedServers=$5

isSuccess=false
maxAttempt=5
attempt=1
echo "Verifying http://${adminPublicIP}:${adminPort}/weblogic/ready"
while [ $attempt -le $maxAttempt ]
do
  echo "Attempt $attempt :- Checking WebLogic admin server is accessible"
  curl http://${adminPublicIP}:${adminPort}/weblogic/ready 
  if [ $? == 0 ]; then
     isSuccess=true
     break
  fi
  attempt=`expr $attempt + 1`
  sleep 2m
done

if [[ $isSuccess == "false" ]]; then
        echo "Failed : WebLogic admin server is not accessible"
        exit 1
else
        echo "WebLogic admin server is accessible"
fi

sleep 1m

# Verifying whether admin console is accessible
echo "Checking WebLogic admin console is acessible"
curl http://${adminPublicIP}:${adminPort}/console/
if [[ $? != 0 ]]; then
   echo "WebLogic admin console is not accessible"
   exit 1
else
   echo "WebLogic admin console is accessible"
fi

#Verifying whether managed servers are up/running
for managedServer in $managedServers
do
  echo "Verifying managed server : $managedServer"
  isSuccess=false
  maxAttempt=3
  attempt=1
  while [ $attempt -le $maxAttempt ]
  do
     curl --user $wlsUserName:$wlspassword -X GET -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverRuntimes/$managedServer" | grep "\"state\": \"RUNNING\""
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
