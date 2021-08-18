# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
./invokeSetupDBConnections.sh
    <aksClusterRGName>
    <aksClusterName>
    <databaseType>
    <dbPassword>
    <dbUser>
    <dsConnectionURL>
    <jdbcDataSourceName>
    <wlsDomainUID>
    <wlsUser>
    <wlsPassword>
    <dbOptType>
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

export aksClusterRGName=$1
export aksClusterName=$2
export databaseType=$3
dbPassword=$4
export dbUser=$5
export dsConnectionURL=$6
export jdbcDataSourceName=$7
export wlsDomainUID=$8
export wlsUser=$9
wlsPassword=${10}
export dbOptType=${11}

echo ${dbPassword} \
    ${wlsPassword} | \
    bash ./setupDBConnections.sh \
    ${aksClusterRGName} \
    ${aksClusterName} \
    ${databaseType} \
    ${dbUser} \
    ${dsConnectionURL} \
    ${jdbcDataSourceName} \
    ${wlsDomainUID} \
    ${wlsUser} \
    ${dbOptType}

if [ $? -ne 0 ]; then
    usage 1
fi
