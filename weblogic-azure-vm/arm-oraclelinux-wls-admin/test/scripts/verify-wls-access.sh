#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Verifying admin server is accessible
adminPublicIP="$1"
adminPort=$2

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
   exit 0
fi
