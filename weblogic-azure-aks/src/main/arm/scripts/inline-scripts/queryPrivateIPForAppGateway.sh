# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
#
# env inputs:
# SUBNET_ID
# KNOWN_IP

function queryIP() {
    echo_stdout "Subnet Id: ${SUBNET_ID}"

    # select a available private IP
    # azure reserves the first 3 private IPs.
    local ret=$(az network vnet check-ip-address \
        --ids ${SUBNET_ID} \
        --ip-address ${KNOWN_IP})
    local available=$(echo ${ret} | jq -r .available)
    if [[ "${available,,}" == "true" ]]; then
      outputPrivateIP=${KNOWN_IP}
    else
      local privateIPAddress=$(echo ${ret} | jq -r .availableIpAddresses[0])
      if [[ -z "${privateIPAddress}" ]] || [[ "${privateIPAddress}"=="null" ]]; then
        echo_stderr "ERROR: make sure there is available IP for application gateway in your subnet."
      fi

      outputPrivateIP=${privateIPAddress}
    fi
}

function output_result() {
  echo "Available Private IP: ${outputPrivateIP}"
  result=$(jq -n -c \
    --arg privateIP "$outputPrivateIP" \
    '{privateIP: $privateIP}')
  echo "result is: $result"
  echo $result >$AZ_SCRIPTS_OUTPUT_PATH
}

# main script
outputPrivateIP="10.0.0.1"

queryIP

output_result