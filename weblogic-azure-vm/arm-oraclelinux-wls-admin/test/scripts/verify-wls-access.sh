#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Verifying admin server is accessible

#read arguments from stdin
read adminPublicIP adminPort

CURL_PARMS="--connect-timeout 60 --max-time 180 --retry 10 --retry-delay 30 --retry-max-time 180  --retry-connrefused"

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
