#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./postDeploymentScript.sh "
}



echo "Executing post Deployment script"

# Get all public ips assigned to the network interface in a given resource group, and follow the below steps
# 1) Get the resource (public IP) tagged with supplied resource tag
# 2) Remove the public IP from netwrok interface
# 3) Finally delete all public IPs    

PUBLIC_IPS="$(az network public-ip list --resource-group ${RESOURCE_GROUP_NAME} --query "[?tags && contains(keys(tags), '${GUID_TAG}')].id" -o tsv)"
if [ -n "${PUBLIC_IPS}" ]; then
	echo "Found public IPs to remove: ${PUBLIC_IPS}"
	for PUBLIC_IP in ${PUBLIC_IPS}; do
		IP_CONFIG_ID=$(az network public-ip show --ids "${PUBLIC_IP}" --query "ipConfiguration.id" -o tsv)
		 if [ -n "${IP_CONFIG_ID}" ]; then
		 	echo "Found IP configuration: ${IP_CONFIG_ID}"
		 	# Using IP configuration id extract Network interface name and IP config name
		 	NIC_NAME=$(echo "${IP_CONFIG_ID}" | sed 's|.*/networkInterfaces/\([^/]*\)/.*|\1|')
		 	IP_CONFIG_NAME=$(echo "${IP_CONFIG_ID}" | sed 's|.*/ipConfigurations/\([^/]*\).*|\1|')
		 	echo "Removing public IP from NIC: ${NIC_NAME}, IP config: ${IP_CONFIG_NAME}"
		 	az network nic ip-config update -g "${RESOURCE_GROUP_NAME}" --nic-name "${NIC_NAME}" -n "${IP_CONFIG_NAME}" --remove publicIPAddress
		 fi
	done
	echo "Deleting public IPs: ${PUBLIC_IPS}"
	az network public-ip delete --ids ${PUBLIC_IPS}
else
	echo "No public IPs found with tag ${GUID_TAG}"
fi
echo "Deleting $MANAGED_IDENTITY_ID	"
az identity delete --ids $MANAGED_IDENTITY_ID