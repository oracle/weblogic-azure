#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to test WebLogic admin, console and managed servers access.

# Verifying admin server is accessible

#read arguments from stdin
read adminPublicIP adminPort wlsUserName wlspassword managedServers

CURL_PARMS="--connect-timeout 60 --max-time 180 --retry 10 --retry-delay 30 --retry-max-time 180 --retry-connrefused"

echo "Verifying http://${adminPublicIP}:${adminPort}/weblogic/ready"
curl ${CURL_PARMS} http://${adminPublicIP}:${adminPort}/weblogic/ready

if [[ $? != 0 ]]; then
        echo "Failed : WebLogic admin server is not accessible"
        exit 1
else
        echo "WebLogic admin server is accessible"
fi

# Verifying whether admin console is accessible
echo "Checking WebLogic admin console is acessible"
curl ${CURL_PARMS} http://${adminPublicIP}:${adminPort}/console/
if [[ $? != 0 ]]; then
   echo "WebLogic admin console is not accessible"
   exit 1
else
   echo "WebLogic admin console is accessible"
   exit 0
fi


#Verifying whether managed servers are up/running
for managedServer in $managedServers
do
  echo "Verifying managed server : $managedServer"
  curl ${CURL_PARMS} --user $wlsUserName:$wlspassword -X GET -H 'X-Requested-By: MyClient' -H 'Content-Type: application/json' -H 'Accept: application/json'  -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverRuntimes/$managedServer" | grep "\"state\": \"RUNNING\""
  if [ $? == 0 ]; then
  	echo "$managedServer managed server is in RUNNING state"
  else
  	echo "$managedServer managed server is not in RUNNING state"
  	exit 1
  fi
done
exit 0
