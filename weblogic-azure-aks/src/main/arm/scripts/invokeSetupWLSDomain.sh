# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
./invokeSetupWLSDomain.sh
    <ocrSSOUser>
    <ocrSSOPSW>
    <aksClusterRGName>
    <aksClusterName>
    <wlsImageTag>
    <acrName>
    <wlsDomainName>
    <wlsDomainUID>
    <wlsUserName>
    <wlsPassword>
    <wdtRuntimePassword>
    <wlsCPU>
    <wlsMemory>
    <managedServerPrefix>
    <appReplicas>
    <appPackageUrls>
    <currentResourceGroup>
    <scriptURL>
    <storageAccountName>
    <wlsClusterSize>
    <enableCustomSSL>
    <wlsIdentityData>
    <wlsIdentityPsw>
    <wlsIdentityType>
    <wlsIdentityAlias>
    <wlsIdentityKeyPsw>
    <wlsTrustData>
    <wlsTrustPsw>
    <wlsTrustType>
    <enablePV>
    <enableT3Tunneling>
    <t3AdminPort>
    <t3ClusterPort>
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
export wlsUserName=$9
wlsPassword=${10}
wdtRuntimePassword=${11}
export wlsCPU=${12}
export wlsMemory=${13}
export managedServerPrefix=${14}
export appReplicas=${15}
export appPackageUrls=${16}
export currentResourceGroup=${17}
export scriptURL=${18}
export storageAccountName=${19}
export wlsClusterSize=${20}
export enableCustomSSL=${21}
export wlsIdentityData=${22}
wlsIdentityPsw=${23}
export wlsIdentityType=${24}
export wlsIdentityAlias=${25}
wlsIdentityKeyPsw=${26}
export wlsTrustData=${27}
wlsTrustPsw=${28}
export wlsTrustType=${29}
export enablePV=${30}
export enableT3Tunneling=${31}
export t3AdminPort=${32}
export t3ClusterPort=${33}

echo ${ocrSSOPSW} \
    ${wlsPassword} \
    ${wdtRuntimePassword} \
    ${wlsIdentityPsw} \
    ${wlsIdentityKeyPsw} \
    ${wlsTrustPsw} | \
    bash ./setupWLSDomain.sh \
    ${ocrSSOUser} \
    ${aksClusterRGName} \
    ${aksClusterName} \
    ${wlsImageTag} \
    ${acrName} \
    ${wlsDomainName} \
    ${wlsDomainUID} \
    ${wlsUserName} \
    ${wlsCPU} \
    ${wlsMemory} \
    ${managedServerPrefix} \
    ${appReplicas} \
    ${appPackageUrls} \
    ${currentResourceGroup} \
    ${scriptURL} \
    ${storageAccountName} \
    ${wlsClusterSize} \
    ${enableCustomSSL} \
    ${wlsIdentityData} \
    ${wlsIdentityType} \
    ${wlsIdentityAlias} \
    ${wlsTrustData} \
    ${wlsTrustType} \
    ${enablePV} \
    ${enableT3Tunneling} \
    ${t3AdminPort} \
    ${t3ClusterPort}

if [ $? -ne 0 ]; then
    usage 1
fi
