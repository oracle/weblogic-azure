# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script  ${0} starts"

# read <spBase64String> <appgwFrontendSSLCertPsw> from stdin
function read_sensitive_parameters_from_stdin() {
  read spBase64String appgwFrontendSSLCertPsw
}

# Install latest kubectl and Helm
function install_utilities() {
  if [ -d "apps" ]; then
    rm apps -f -r
  fi

  mkdir apps
  cd apps

  # Install kubectl
  install_kubectl
}

#Function to display usage message
function usage() {
  usage=$(
    cat <<-END
Usage:
echo <spBase64String> <appgwFrontendSSLCertPsw> | 
  ./setupNetworking.sh
    <aksClusterRGName>
    <aksClusterName>
    <wlsDomainName>
    <wlsDomainUID>
    <lbSvcValues>
    <enableAppGWIngress>
    <subID>
    <curRGName>
    <appgwName>
    <appgwUsePrivateIP>
    <appgwForAdminServer>
    <enableCustomDNSAlias>
    <dnsRGName>
    <dnsZoneName>
    <dnsAdminLabel>
    <dnsClusterLabel>
    <appgwAlias>
    <enableInternalLB>
    <appgwFrontendSSLCertData>
    <appgwCertificateOption>
    <enableCustomSSL>
    <enableCookieBasedAffinity>
    <enableRemoteConsole>
    <dnszoneAdminT3ChannelLabel>
    <dnszoneClusterT3ChannelLabel>
END
  )
  echo_stdout ${usage}
  if [ $1 -eq 1 ]; then
    echo_stderr ${usage}
    exit 1
  fi
}

#Function to validate input
function validate_input() {
  if [[ -z "$aksClusterRGName" || -z "${aksClusterName}" ]]; then
    echo_stderr "AKS cluster name and resource group name are required. "
    usage 1
  fi

  if [[ -z "$wlsDomainName" || -z "${wlsDomainUID}" ]]; then
    echo_stderr "WebLogic domain name and WebLogic domain UID are required. "
    usage 1
  fi

  if [ -z "$lbSvcValues" ]; then
    echo_stderr "lbSvcValues is required. "
    usage 1
  fi

  if [ -z "$enableAppGWIngress" ]; then
    echo_stderr "enableAppGWIngress is required. "
    usage 1
  fi

  if [ -z "$subID" ]; then
    echo_stderr "subID is required. "
    usage 1
  fi

  if [ -z "$curRGName" ]; then
    echo_stderr "curRGName is required. "
    usage 1
  fi

  if [ -z "$appgwName" ]; then
    echo_stderr "appgwName is required. "
    usage 1
  fi

  if [ -z "$appgwUsePrivateIP" ]; then
    echo_stderr "appgwUsePrivateIP is required. "
    usage 1
  fi

  if [ -z "$spBase64String" ]; then
    echo_stderr "spBase64String is required. "
    usage 1
  fi

  if [ -z "$appgwForAdminServer" ]; then
    echo_stderr "appgwForAdminServer is required. "
    usage 1
  fi

  if [ -z "$enableCustomDNSAlias" ]; then
    echo_stderr "enableCustomDNSAlias is required. "
    usage 1
  fi

  if [[ -z "$dnsRGName" || -z "${dnsZoneName}" ]]; then
    echo_stderr "dnsZoneName and dnsRGName are required. "
    usage 1
  fi

  if [ -z "$dnsAdminLabel" ]; then
    echo_stderr "dnsAdminLabel is required. "
    usage 1
  fi

  if [ -z "$dnsClusterLabel" ]; then
    echo_stderr "dnsClusterLabel is required. "
    usage 1
  fi

  if [ -z "$appgwAlias" ]; then
    echo_stderr "appgwAlias is required. "
    usage 1
  fi

  if [ -z "$enableInternalLB" ]; then
    echo_stderr "enableInternalLB is required. "
    usage 1
  fi

  if [[ -z "$appgwFrontendSSLCertData" || -z "${appgwFrontendSSLCertPsw}" ]]; then
    echo_stderr "appgwFrontendSSLCertData and appgwFrontendSSLCertPsw are required. "
    usage 1
  fi

  if [ -z "$enableCustomSSL" ]; then
    echo_stderr "enableCustomSSL is required. "
    usage 1
  fi

  if [ -z "$enableCookieBasedAffinity" ]; then
    echo_stderr "enableCookieBasedAffinity is required. "
    usage 1
  fi

  if [ -z "$enableRemoteConsole" ]; then
    echo_stderr "enableRemoteConsole is required. "
    usage 1
  fi

  if [ -z "$dnszoneAdminT3ChannelLabel" ]; then
    echo_stderr "dnszoneAdminT3ChannelLabel is required. "
    usage 1
  fi

  if [ -z "$dnszoneClusterT3ChannelLabel" ]; then
    echo_stderr "dnszoneClusterT3ChannelLabel is required. "
    usage 1
  fi
}

# Connect to AKS cluster
function connect_aks_cluster() {
  az aks get-credentials --resource-group ${aksClusterRGName} --name ${aksClusterName} --overwrite-existing
}

function create_svc_lb() {
  # No lb svc inputs
  if [[ "${lbSvcValues}" != "[]" ]]; then
    chmod ugo+x $scriptDir/createLbSvc.sh
    bash $scriptDir/createLbSvc.sh \
      ${enableInternalLB} \
      ${enableCustomSSL} \
      ${enableCustomDNSAlias} \
      ${dnsRGName} \
      ${dnsZoneName} \
      ${dnsAdminLabel} \
      ${dnszoneAdminT3ChannelLabel} \
      ${dnsClusterLabel} \
      ${dnszoneClusterT3ChannelLabel} \
      "${lbSvcValues}" \
      ${wlsDomainUID}
  fi
}

function create_appgw_ingress() {
  if [[ "${enableAppGWIngress,,}" == "true" ]]; then
    chmod ugo+x $scriptDir/createAppGatewayIngress.sh
    echo "$spBase64String" "$appgwFrontendSSLCertPsw" |
      bash $scriptDir/createAppGatewayIngress.sh \
        ${aksClusterRGName} \
        ${aksClusterName} \
        ${wlsDomainUID} \
        ${subID} \
        ${curRGName} \
        ${appgwName} \
        ${appgwUsePrivateIP} \
        ${appgwForAdminServer} \
        ${enableCustomDNSAlias} \
        ${dnsRGName} \
        ${dnsZoneName} \
        ${dnsAdminLabel} \
        ${dnsClusterLabel} \
        ${appgwAlias} \
        ${appgwFrontendSSLCertData} \
        ${appgwCertificateOption} \
        ${enableCustomSSL} \
        ${enableCookieBasedAffinity} \
        ${enableRemoteConsole}
  fi
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
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
export appgwUsePrivateIP=${10}
export appgwForAdminServer=${11}
export enableCustomDNSAlias=${12}
export dnsRGName=${13}
export dnsZoneName=${14}
export dnsAdminLabel=${15}
export dnsClusterLabel=${16}
export appgwAlias=${17}
export enableInternalLB=${18}
export appgwFrontendSSLCertData=${19}
export appgwCertificateOption=${20}
export enableCustomSSL=${21}
export enableCookieBasedAffinity=${22}
export enableRemoteConsole=${23}
export dnszoneAdminT3ChannelLabel=${24}
export dnszoneClusterT3ChannelLabel=${25}

read_sensitive_parameters_from_stdin

validate_input

install_utilities

connect_aks_cluster

create_svc_lb

create_appgw_ingress
