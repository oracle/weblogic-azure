# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

function echo_stderr() {
    >&2 echo "$@"
    echo "$@" >>stdout
}

function echo_stdout() {
    echo "$@" 
    echo "$@" >>stdout
}

#Function to display usage message
function usage() {
    echo_stdout "./invokeSetupWLSDomain.sh ..."
    if [ $1 -eq 1 ]; then
        exit 1
    fi
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

export ocrSSOUser=${1}
ocrSSOPSW=${2}
export aksClusterRGName=${3}
export aksClusterName=${4}
export wlsImageTag=${5}
export acrName=${6}
export wlsDomainName=${7}
export wlsDomainUID=${8}
export wlsUserName=${9}
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

echo ${ocrSSOPSW} ${wlsPassword} ${wdtRuntimePassword} | bash ./setupWLSDomain.sh ${ocrSSOUser} ${aksClusterRGName} ${aksClusterName} ${wlsImageTag} ${acrName} ${wlsDomainName} ${wlsDomainUID} ${wlsUserName} ${wlsCPU} ${wlsMemory} ${managedServerPrefix} ${appReplicas} ${appPackageUrls} ${currentResourceGroup} ${scriptURL} ${storageAccountName} ${wlsClusterSize}


exit $exitCode
