#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#
# Description
#  This script is to configure custom DNS alias for Weblogic Server Administration Console.
#  It supports two scenarios:
#      * If you have an Azure DNS Zone, create DNS alias for admin console on the existing DNS Zone.
#      * If you don’t have an Azure DNS Zone, create the DNS Zone in the same resource group of WebLogic server, and create DNS alias for admin console.

# Initialize
script="${BASH_SOURCE[0]}"
scriptDir="$(cd "$(dirname "${script}")" && pwd)"

function usage() {
  cat <<EOF
Options:
        --admin-vm-name           (Required)       The name of virtual machine that hosts WebLogic Admin Server
        --admin-console-label     (Required)       Specify a lable to generate the DNS alias for WebLogic Administration Console
        -f   --artifact-location  (Required)       ARM Template URL
        -g   --resource-group     (Required)       The name of resource group that has WebLogic cluster deployed
        -l   --location           (Required)       Location of current cluster resources.
        -z   --zone-name          (Required)       DNS Zone name
        --identity-id             (Optional)       Specify an Azure Managed User Identity to update DNS Zone
        --zone-resource-group     (Optional)       The name of resource group that has WebLogic cluster deployed
        -h   --help

Samples:
        1. Configure DNS alias on an existing DNS Zone
          ./custom-dns-alias-cli.sh \\
            --resource-group <your-resource-group> \\
            --admin-vm-name adminVM \\
            --admin-console-label admin \\
            --artifact-location <artifact-location> \\
            --location eastus \\
            --zone-name contoso.com \\
            --identity-id <your-identity-id> \\
            --zone-resource-group haiche-dns-test1

        2. Configure DNS alias on a new DNS Zone
          ./custom-dns-alias-cli.sh \\
            --resource-group <your-resource-group> \\
            --admin-vm-name adminVM \\
            --admin-console-label admin \\
            --artifact-location <artifact-location> \\
            --location eastus \\
            --zone-name contoso.com

EOF
}

function validateInput() {
  if [ -z "${resourceGroup}" ]; then
    echo "Option --resource-group is required."
    exit 1
  fi
  if [ -z "${artifactLocation}" ]; then
    echo "Option --artifact-location is required."
    exit 1
  fi

  templateURL="${artifactLocation}nestedtemplates/dnszonesTemplate.json"
  if [ -z "${templateURL}" ]; then
    echo "Option --artifact-location is required."
    exit 1
  else
    if curl --output /dev/null --silent --head --fail "${templateURL}"; then
      echo "ARM Tempalte exists: $templateURL"
    else
      echo "ARM Tempalte does not exist: $templateURL"
      exit 1
    fi
  fi
  if [ -z "${zoneName}" ]; then
    echo "Option --zone-name is required."
    exit 1
  fi
  if [ -z "${adminVMName}" ]; then
    echo "Option --admin-vm-name is required."
    exit 1
  fi
  if [ -z "${adminLabel}" ]; then
    echo "Option --admin-console-label is required."
    exit 1
  fi

  if [ -n "${zoneResourceGroup}" ]; then
    hasDNSZone=true
  fi
}

function queryAdminIPId() {
  az extension add --name resource-graph;

  nicId=$(az graph query -q "Resources 
    | where type =~ 'microsoft.compute/virtualmachines' 
    | where name=~ '${adminVMName}' 
    | where resourceGroup =~ '${resourceGroup}' 
    | extend nics=array_length(properties.networkProfile.networkInterfaces) 
    | mv-expand nic=properties.networkProfile.networkInterfaces 
    | where nics == 1 or nic.properties.primary =~ 'true' or isempty(nic) 
    | project nicId = tostring(nic.id)" -o tsv)

  if [ -z "${nicId}" ]; then
    echo "Please make sure admin VM '${adminVMName}' exists in resource group '${resourceGroup}'. "
    exit 1
  fi

  export adminIPId=$(az graph query -q "Resources 
    | where type =~ 'microsoft.network/networkinterfaces' 
    | where id=~ '${nicId}' 
    | extend ipConfigsCount=array_length(properties.ipConfigurations) 
    | mv-expand ipconfig=properties.ipConfigurations 
    | where ipConfigsCount == 1 or ipconfig.properties.primary =~ 'true' 
    | project  publicIpId = tostring(ipconfig.properties.publicIPAddress.id)" -o tsv)

  if [ -z "${adminIPId}" ]; then
    echo "Can not query public IP of admin VM. Please make sure admin VM '${adminVMName}' exists in resource group '${resourceGroup}'. "
    exit 1
  fi
}

function generateParameterFile() {
  export parametersPath=parameters.json
  cat <<EOF >${scriptDir}/${parametersPath}
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "${artifactLocation}"
        },
        "_artifactsLocationSasToken": {
            "value": ""
        },
        "dnszonesARecordSetNames": {
            "value": [
              "$adminLabel"
            ]
        },
        "dnszonesCNAMEAlias": {
            "value": [
            ]
        },
        "dnszonesCNAMERecordSetNames": {
            "value": [
            ]
        },
        "dnszoneName": {
            "value": "${zoneName}"
        },
        "hasDNSZones": {
            "value": ${hasDNSZone}
        },
        "identity": {
            "value": {
              "type": "UserAssigned",
              "userAssignedIdentities": {
                "${identity}": {}
              }
            }
        },
        "location": {
            "value": "${location}"
        },
        "resourceGroup": {
            "value": "${zoneResourceGroup}"
        },
        "targetResources": {
            "value": [
              "${adminIPId}"
            ]
        }
    }
}
EOF
}

function invoke() {
  # validate the template
  az deployment group validate --verbose \
    --resource-group ${resourceGroup} \
    --parameters @${scriptDir}/${parametersPath} \
    --template-uri ${templateURL}

  # invoke the template
  az deployment group create --verbose \
    --resource-group ${resourceGroup} \
    --parameters @${scriptDir}/${parametersPath} \
    --template-uri ${templateURL} \
    --name "configure-custom-dns-alias-$(date +"%s")"

  # exit if error happens
  if [ $? -eq 1 ]; then
    exit 1
  fi
}

function cleanup() {
  if test -f "${scriptDir}/${parametersPath}"; then
    rm -f ${scriptDir}/${parametersPath}
  fi
}

function printSummary() {
  echo ""
  echo ""
  echo "
DONE!
  "
  if [ "${hasDNSZone}" == "false" ]; then
    nameServers=$(az network dns zone show -g ${resourceGroup} --name ${zoneName} --query nameServers)
    echo "
Action required:
  Complete Azure DNS delegation to make the alias accessible.
  Reference: https://aka.ms/dns-domain-delegation
  Name servers:
  ${nameServers}
  "
  fi

  echo "
Custom DNS alias:
    Resource group: ${resourceGroup}
    WebLogic Server Administration Console URL: http://${adminLabel}.${zoneName}:7001/console
    WebLogic Server Administration Console secured URL: https://${adminLabel}.${zoneName}:7002/console
  "
}

# main script start from here
# default value
export hasDNSZone=false
export identity=/subscriptions/subscriptionId/resourceGroups/TestResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/TestUserIdentity1

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
  "--help") set -- "$@" "-h" ;;
  "--resource-group") set -- "$@" "-g" ;;
  "--artifact-location") set -- "$@" "-f" ;;
  "--zone-name") set -- "$@" "-z" ;;
  "--admin-vm-name") set -- "$@" "-m" ;;
  "--admin-console-label") set -- "$@" "-c" ;;
  "--zone-resource-group") set -- "$@" "-r" ;;
  "--identity-id") set -- "$@" "-i" ;;
  "--location") set -- "$@" "-l" ;;
  "--"*)
    set -- usage
    exit 2
    ;;
  *) set -- "$@" "$arg" ;;
  esac
done

# Parse short options
OPTIND=1
while getopts "hg:f:z:m:c:w:r:i:l:" opt; do
  case "$opt" in
  "g") resourceGroup="$OPTARG" ;;
  "f") artifactLocation="$OPTARG" ;;
  "h")
    usage
    exit 0
    ;;
  "z") zoneName="$OPTARG" ;;
  "m") adminVMName="$OPTARG" ;;
  "c") adminLabel="$OPTARG" ;;
  "r") zoneResourceGroup="$OPTARG" ;;
  "i") identity="$OPTARG" ;;
  "l") location="$OPTARG" ;;
  esac
done
shift $(expr $OPTIND - 1)

validateInput
cleanup
queryAdminIPId
generateParameterFile
invoke
cleanup
printSummary
