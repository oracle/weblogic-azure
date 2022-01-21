# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to test WebLogic cluster domain managed servers lifecycle. 

read wlsUserName wlspassword adminPublicIP adminPort managedServers

CURL_REQD_PARMS="-s -v --user ${wlsUserName}:${wlspassword} -H X-Requested-By:MyClient -H Content-Type:application/json -H Accept:application/json"
CURL_RETRY_PARMS="--connect-timeout 60 --max-time 180 --retry 10 --retry-delay 30 --retry-max-time 180 --retry-connrefused "
# Shutdown the server and verify whether it is in SHUTDOWN state
# Restart the managed server
for managedServer in $managedServers
do
	echo "Shut down managed server : $managedServer"
	attempt=0
	while [ $attempt -le 5 ]
	do
		echo "Attempt to shutdown $attempt"
		echo curl ${CURL_REQD_PARMS} -X POST  -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer/forceShutdown" --data "{}" 
		curl ${CURL_REQD_PARMS} -X POST  -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer/forceShutdown" --data "{}" > out
		echo "Response received for shutdown REST command"
		cat out
		echo "Attempt to verify shutdown $attempt"
		echo curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -X GET  -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${managedServer}?links=none" 
		curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -X GET -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${managedServer}?links=none" > out
		echo "Recevied response for shutdown verification"
		cat out
		cat out | grep "\"state\": \"SHUTDOWN\""
		if [ $? == 0 ]; then
			echo "$managedServer managed server is in SHUTDOWN state as expected"
			break
		elif [[ $? != 0 ]] && [[ $attempt -ge 5 ]]; then
			echo "$managedServer managed server is not in SHUTDOWN state after multiple attempts"
			exit 1
		fi 
		attempt=$((attempt+1))
		sleep 30s
	done   

   	echo "Starting managed server $managedServer"
   	attempt=0
  	while [ $attempt -le 5 ]
  	do
  		echo "Attempt to starting server $attempt"
   		echo curl ${CURL_REQD_PARMS}  -X POST -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer/start" --data "{}"	
		curl ${CURL_REQD_PARMS} -X POST -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/$managedServer/start" --data "{}" > out
		echo "Response received for start REST command"
		cat out
		
		echo "Attempt to verify start $attempt"
		echo curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -X GET -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${managedServer}?links=none"
		curl ${CURL_REQD_PARMS} ${CURL_RETRY_PARMS} -X GET -i "http://${adminPublicIP}:${adminPort}/management/weblogic/latest/domainRuntime/serverLifeCycleRuntimes/${managedServer}?links=none" > out
		echo "Recevied response for start verification"
		cat out
		cat out | grep "\"state\": \"RUNNING\""
		if [ $? == 0 ]; then
			echo "$managedServer managed server is in RUNNING state as expected"
			break
		elif [[ $retVal != 0 ]] && [[ $attempt -ge 5 ]]; then
			echo "$managedServer managed server is not in RUNNING state after multiple attempts"
			exit 1	 
		fi 
    	attempt=$((attempt+1))
    	sleep 1m
    done
done  
exit 0
