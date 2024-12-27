#!/bin/bash
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Verify the service using systemctl status
function verifyServiceStatus()
{
  serviceName=$1
  systemctl status $serviceName | grep "active (running)"    
  if [[ $? != 0 ]]; then
     echo "$serviceName is not in active (running) state"
     exit 1
  fi
  echo "$serviceName is active (running)"
}

#Verify the service using systemctl is-active
function verifyServiceActive()
{
  serviceName=$1
  state=$(systemctl is-active $serviceName)
  if [[ $state == "active" ]]; then
     echo "$serviceName is active"
  else
     echo "$serviceName is not active"
     exit 1
  fi
}

echo "Testing on admin server"
servicesList="rngd wls_admin"

for service in $servicesList
do
   verifyServiceStatus $service
   verifyServiceActive $service
done

exit 0
