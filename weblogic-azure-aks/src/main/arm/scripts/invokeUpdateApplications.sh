# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
./invokeUpdateApplications.sh
    <ocrSSOUser>
    <ocrSSOPSW>
    <aksClusterRGName>
    <aksClusterName>
    <wlsImageTag>
    <acrName>
    <wlsDomainName>
    <wlsDomainUID>
    <currentResourceGroup>
    <appPackageUrls>
    <scriptURL>
    <appStorageAccountName>
    <appContainerName>
END
)
    echo_stdout "${usage}"
    if [ $1 -eq 1 ]; then
        echo_stderr "${usage}"
        exit 1
    fi
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/utility.sh

export ocrSSOUser=$1
ocrSSOPSW=$2
export aksClusterRGName=$3
export aksClusterName=$4
export wlsImageTag=$5
export acrName=$6
export wlsDomainName=$7
export wlsDomainUID=$8
export currentResourceGroup=$9
export appPackageUrls=${10}
export scriptURL=${11}
export appStorageAccountName=${12}
export appContainerName=${13}

echo ${ocrSSOPSW} | \
    bash ./updateApplications.sh \
    ${ocrSSOUser} \
    ${aksClusterRGName} \
    ${aksClusterName} \
    ${wlsImageTag} \
    ${acrName} \
    ${wlsDomainName} \
    ${wlsDomainUID} \
    ${currentResourceGroup} \
    ${appPackageUrls} \
    ${scriptURL} \
    ${appStorageAccountName} \
    ${appContainerName}

if [ $? -ne 0 ]; then
    usage 1
fi
