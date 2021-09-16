# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description: to create DNS record in an existing DNS Zone.

echo "Script  ${0} starts"

# Initialize
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/utility.sh

# create dns alias for lb service
# $1: ipv4 address
# $2: label of subdomain
# $3: resource group name that has the DNS Zone.
# $4: DNS Zone name
function create_dns_A_record() {
    ipv4Addr=$1
    label=$2
    dnsRGName=$3
    dnsZoneName=$4

    az network dns record-set a add-record --ipv4-address ${ipv4Addr} \
        --record-set-name ${label} \
        --resource-group ${dnsRGName} \
        --zone-name ${dnsZoneName}
    
    if [ $? != 0 ]; then
        echo_stderr "Failed to create DNS record: ${label}.${dnsZoneName}, ipv4: ${ipv4Addr}"
        exit 1 
    fi
}

# create dns alias for app gateway
# $1: ipv4 address
# $2: label of subdomain
# $3: resource group name that has the DNS Zone.
# $4: DNS Zone name
function create_dns_CNAME_record() {
    cname=$1
    label=$2
    dnsRGName=$3
    dnsZoneName=$4

    az network dns record-set cname create \
        -g ${dnsRGName} \
        -z ${dnsZoneName} \
        -n ${label}

    az network dns record-set cname set-record \
        -g ${dnsRGName} \
        -z ${dnsZoneName} \
        --cname ${cname} \
        --record-set-name ${label}

    if [ $? != 0 ]; then
        echo_stderr "Failed to create DNS record: ${label}.${dnsZoneName}, cname: ${cname}"
        exit 1
    fi
}
