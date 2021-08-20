# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
./invokeSetupNetworking.sh
    <aksClusterRGName>
    <aksClusterName>
    <wlsDomainName>
    <wlsDomainUID>
    <lbSvcValues>
    <enableAppGWIngress>
    <subID>
    <curRGName>
    <appgwName>
    <vnetName>
    <spBase64String>
    <appgwForAdminServer>
    <enableCustomDNSAlias>
    <dnsRGName>
    <dnsZoneName>
    <dnsAdminLabel>
    <dnsClusterLabel>
    <appgwAlias>
    <enableInternalLB>
    <appgwFrontendSSLCertData>
    <appgwFrontendSSLCertPsw>
    <appgwCertificateOption>
    <enableCustomSSL>
    <enableCookieBasedAffinity>
    <enableRemoteConsole>
    <dnszoneAdminT3ChannelLabel>
    <dnszoneClusterT3ChannelLabel>
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
export wlsDomainName=$3
export wlsDomainUID=$4
export lbSvcValues=$5
export enableAppGWIngress=$6
export subID=$7
export curRGName=${8}
export appgwName=${9}
export vnetName=${10}
spBase64String=${11}
export appgwForAdminServer=${12}
export enableCustomDNSAlias=${13}
export dnsRGName=${14}
export dnsZoneName=${15}
export dnsAdminLabel=${16}
export dnsClusterLabel=${17}
export appgwAlias=${18}
export enableInternalLB=${19}
export appgwFrontendSSLCertData=${20}
appgwFrontendSSLCertPsw=${21}
export appgwCertificateOption=${22}
export enableCustomSSL=${23}
export enableCookieBasedAffinity=${24}
export enableRemoteConsole=${25}
export dnszoneAdminT3ChannelLabel=${26}
export dnszoneClusterT3ChannelLabel=${27}

echo ${spBase64String} \
    ${appgwFrontendSSLCertPsw} | \
    bash ./setupNetworking.sh \
    ${aksClusterRGName} \
    ${aksClusterName} \
    ${wlsDomainName} \
    ${wlsDomainUID} \
    ${lbSvcValues} \
    ${enableAppGWIngress} \
    ${subID} \
    ${curRGName} \
    ${appgwName} \
    ${vnetName} \
    ${appgwForAdminServer} \
    ${enableCustomDNSAlias} \
    ${dnsRGName} \
    ${dnsZoneName} \
    ${dnsAdminLabel} \
    ${dnsClusterLabel} \
    ${appgwAlias} \
    ${enableInternalLB} \
    ${appgwFrontendSSLCertData} \
    ${appgwCertificateOption} \
    ${enableCustomSSL} \
    ${enableCookieBasedAffinity} \
    ${enableRemoteConsole} \
    ${dnszoneAdminT3ChannelLabel} \
    ${dnszoneClusterT3ChannelLabel}

if [ $? -ne 0 ]; then
    usage 1
fi
