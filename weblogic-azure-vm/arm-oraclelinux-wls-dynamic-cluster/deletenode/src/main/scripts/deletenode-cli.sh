#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#
# Description
#  This script deletes managed nodes from an existing dynamic WebLogic cluster and removes related Azure resources. 
#  It removes Azure resources including: 
#      * Virtual Machines that host deleting managed servers.
#      * Data disks attached to the Virtual Machines
#      * OS disks attached to the Virtual Machines
#      * Network Interfaces added to the Virtual Machines
#      * Public IPs added to the Virtual Machines
#
#  The following pre-requisites must be handled prior to running this script:
#    * Azure Dynamic WebLogic Cluster application has deployed, the dynamic WebLogic cluster has an Adminstration Server.
#    * The dynamic WebLogic cluster has as least one managed nodes
#    * Azure CLI is installed
#    * Azure CLI has authorized to manage Azure resources
#

# Initialize
script="${BASH_SOURCE[0]}"
scriptDir="$( cd "$( dirname "${script}" )" && pwd )"

function usage {
  echo usage: ${script} -g resource-group [-f template-file] [-u template-url] -p paramter-file [-s silent-mode] [-h]
  echo "  -g Azure Resource Group of the Vitural Machines that host deleting manages servers, must be specified."
  echo "  -f Path of ARM template to delete nodes, must be specified -f option or -u option."
  echo "  -u URL of ARM template, must be specified -f option or -u option."
  echo "  -p Path of ARM parameter, must be specified. "
  echo "  -s Execute the script in silent mode. The script will input y automatically for the prompt."
  echo "  -h Help"
  exit $1
}

silent=false

#
# Parse the command line options
#
while getopts "shg:f:u:p:" opt; do
  case $opt in
    g) resourceGroup="${OPTARG}"
    ;;
    f) templateFile="${OPTARG}"
    ;;
    u) templateURL="${OPTARG}"
    ;;
    p) parametersFile="${OPTARG}"
    ;;
    s) silent=true
    ;;
    h) usage 0
    ;;
    *) usage 1
    ;;
  esac
done


function initialize {
    validateErrors=false

    if [ -z "${resourceGroup}" ]; then
        echo "You must use the -g option to specify resource group." >&2
        validateErrors=true
    fi

    if [[ -z "${templateFile}" && -z "${templateURL}" ]]; then 
        echo "You must use the -f option or -u option to specify tempalte path." >&2
        validateErrors=true
    fi

    if [ -n "${templateFile}" ]; then
        if [ ! -f ${templateFile} ]; then
            echo "Unable to locate the template ${templateFile}" >&2
            validateErrors=true
        fi
    fi

    if [ -z "${parametersFile}" ]; then
        echo "You must use the -p option to specify the path of ARM parameters." >&2
        validateErrors=true
    else
        if [ ! -f ${parametersFile} ]; then
            echo "Unable to locate the parameter ${parametersFile}" >&2
            validateErrors=true
        fi
    fi

    if [ ${validateErrors} == true ]; then
        usage 1
    fi
}

function removeManagedNodes {
    # validate template
    templateArgument="-u ${templateURL}"
    if [ -n "${templateFile}" ];then
        templateArgument="-f ${templateFile}"
    fi

    az deployment group validate \
    -g ${resourceGroup} \
    ${templateArgument} \
    -p @${parametersFile} \
    --no-prompt

    if [ $? -ne 0 ]; then
        echo "Error happens on template or parameters."
        exit 1
    fi

    # delete nodes from dynamic weblogic cluster
    commandsToDeleteAzureResource=$(az deployment group create --verbose -g ${resourceGroup} ${templateArgument} -p @${parametersFile} -n ${deploymentName} --no-prompt --query properties.outputs.commandsToDeleteAzureResource.value)
    if [ $? -ne 0 ]; then
        echo "Error happens on template deployment."
        exit 1
    fi

    # delete azure resources of the nodes
    commandsToDeleteAzureResource=$(echo "${commandsToDeleteAzureResource}" | sed "s/\\\\\"/\"/g" | sed "s/\\\\n/n/g" | sed "s/\\\\\"/\"/g")
    commandsToDeleteAzureResource=$(echo ${commandsToDeleteAzureResource:1:${#commandsToDeleteAzureResource}-2})
    cat <<EOF >remove-azure-resource.sh
${commandsToDeleteAzureResource}
EOF

    chmod ugo+x ./remove-azure-resource.sh
    if [ $silent == true ];then
        echo "y" | ./remove-azure-resource.sh
    else ./remove-azure-resource.sh
    fi

    if [ $? -eq 0 ]; then
        echo ""
        echo ""
        echo "Complete!"
    fi

    rm -f ./remove-azure-resource.sh
}



export deploymentName="deletenode-$(date +"%s")"

initialize
removeManagedNodes
