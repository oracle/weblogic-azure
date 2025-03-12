#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
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

# Pass the services to be checked based on admin/managed servers
# For admin server    : rngd wls_admin wls_nodemanager
# For managed server  : rngd wls_nodemanager

servicesList="rngd wls_nodemanager"

for service in $servicesList
do
   verifyServiceStatus $service
   verifyServiceActive $service
done

exit 0

