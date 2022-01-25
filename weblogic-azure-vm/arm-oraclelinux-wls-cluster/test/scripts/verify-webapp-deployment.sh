#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to test webapp application deployed on WebLogic cluster domain.

# Verifying webapp deployment
read appGatewayURL

CURL_RETRY_PARMS="--connect-timeout 60 --max-time 180 --retry 10 --retry-delay 30 --retry-max-time 180 --retry-connrefused"

echo "Verifying WebLogic Cafe is deployed as expected"
curl --verbose http://${appGatewayURL}/weblogic-cafe/rest/coffees
response=$(curl ${CURL_RETRY_PARMS}  --write-out '%{http_code}' --silent --output /dev/null http://${appGatewayURL}/weblogic-cafe/rest/coffees)
echo "$response"
if [ "$response" -ne 200 ]; then
   echo "WebLogic Cafe is not accessible"
   exit 1
else
   echo "WebLogic Cafe is accessible"
fi
exit 0
