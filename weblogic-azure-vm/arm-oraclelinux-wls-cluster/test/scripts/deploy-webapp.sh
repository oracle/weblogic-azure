#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to test application deployment on WebLogic cluster domain.

# Verifying admin server is accessible

read wlsUserName wlspassword adminVMDNS adminPort

CURL_REQD_PARMS="--user ${wlsUserName}:${wlspassword} -H X-Requested-By:MyClient  -H Accept:application/json -s -v"
CURL_RETRY_PARMS="--connect-timeout 60 --max-time 180 --retry 10 --retry-delay 30 --retry-max-time 180 --retry-connrefused"

echo "curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:multipart/form-data  \
-H "weblogic.edit.session: default" \
-F \"model={
  name:    'weblogic-cafe',
  targets: [ { identity: [ 'clusters', 'cluster1' ] } ]
}\" \
-F \"sourcePath=@weblogic-on-azure/javaee/weblogic-cafe/target/weblogic-cafe.war\" \
-X Prefer:respond-async \
-X POST http://${adminVMDNS}:${adminPort}/management/weblogic/latest/edit/appDeployments"

# Deploy webapp to weblogic server
curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:multipart/form-data  \
-H "weblogic.edit.session: default" \
-F "model={
  name:    'weblogic-cafe',
  targets: [ { identity: [ 'clusters', 'cluster1' ] } ]
}" \
-F "sourcePath=@weblogic-on-azure/javaee/weblogic-cafe/target/weblogic-cafe.war" \
-H "Prefer:respond-async" \
-X POST http://${adminVMDNS}:${adminPort}/management/weblogic/latest/edit/appDeployments > out

echo "Deployment response received"
cat out

attempt=0
while [ $attempt -le 10 ]
do
	curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} \
		-X GET -i "http://${adminVMDNS}:${adminPort}/management/weblogic/latest/domainRuntime/deploymentManager/deploymentProgressObjects/weblogic-cafe?links=none" > out
	echo "Checking deployment operation is completed"
	cat out | grep "\"state\": \"STATE_COMPLETED\""
	if [ $? == 0 ]; then
		echo "Deployment operation is completed"
		cat out
		break
	fi
	attempt=$((attempt+1))
	sleep 10s
done

echo "Verifying the deployed application status"
sleep 1m

attempt=0
while [ $attempt -le 5 ]
do
	echo "curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:application/json -d {target='cluster1'} -X POST  -i http://${adminVMDNS}:${adminPort}/management/weblogic/latest/domainRuntime/deploymentManager/appDeploymentRuntimes/weblogic-cafe/getState" 
	curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:application/json \
	-d "{target='cluster1'}" \
		-X POST  -i "http://${adminVMDNS}:${adminPort}/management/weblogic/latest/domainRuntime/deploymentManager/appDeploymentRuntimes/weblogic-cafe/getState" > out
	
	echo "Deployment state received"
	cat out
	cat out | grep "\"return\": \"STATE_ACTIVE\""
	if [ $? == 0 ]; then
	  echo "Application is deployed successfully and in active state"
	  exit 0
	elif [[ $? != 0 ]] && [[ $attempt -ge 5 ]]; then
	  echo "Application deployment is unsuccessful"
	  exit 1
	fi
	
	cat out | grep "\"return\": \"STATE_PREPARED\""
	if [[ $? == 0 ]]; then
	  # Ideally this is not required but noticed only for 122130 OL7.4 it is required	
	  echo "Starting the service explicitly"
	  echo "curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:application/json -d {} -X POST  -i http://${adminVMDNS}:${adminPort}/management/weblogic/latest/domainRuntime/deploymentManager/appDeploymentRuntimes/weblogic-cafe/start" 
	  curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -H Content-Type:application/json \
	     -d "{}" \
	     -X POST  -i "http://${adminVMDNS}:${adminPort}/management/weblogic/latest/domainRuntime/deploymentManager/appDeploymentRuntimes/weblogic-cafe/start" 
	fi 
	
	attempt=$((attempt+1))
	sleep 1m	
done
