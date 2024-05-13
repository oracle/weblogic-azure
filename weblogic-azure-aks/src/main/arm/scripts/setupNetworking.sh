# Copyright (c) 2021, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script  ${0} starts"

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

#Function to validate input
function validate_input() {
  if [[ -z "$AKS_CLUSTER_RG_NAME" || -z "${AKS_CLUSTER_NAME}" ]]; then
    echo_stderr "AKS cluster name and resource group name are required. "
    exit 1
  fi

  if [[ -z "$WLS_DOMAIN_NAME" || -z "${WLS_DOMAIN_UID}" ]]; then
    echo_stderr "WebLogic domain name and WebLogic domain UID are required. "
    exit 1
  fi

  if [ -z "$LB_SVC_VALUES" ]; then
    echo_stderr "LB_SVC_VALUES is required. "
    exit 1
  fi

  if [ -z "$ENABLE_AGIC" ]; then
    echo_stderr "ENABLE_AGIC is required. "
    exit 1
  fi

  if [ -z "$CURRENT_RG_NAME" ]; then
    echo_stderr "CURRENT_RG_NAME is required. "
    exit 1
  fi

  if [ -z "$APPGW_NAME" ]; then
    echo_stderr "APPGW_NAME is required. "
    exit 1
  fi

  if [ -z "$APPGW_USE_PRIVATE_IP" ]; then
    echo_stderr "APPGW_USE_PRIVATE_IP is required. "
    exit 1
  fi

  if [ -z "$APPGW_FOR_ADMIN_SERVER" ]; then
    echo_stderr "APPGW_FOR_ADMIN_SERVER is required. "
    exit 1
  fi

  if [ -z "$ENABLE_DNS_CONFIGURATION" ]; then
    echo_stderr "ENABLE_DNS_CONFIGURATION is required. "
    exit 1
  fi

  if [[ -z "$DNS_ZONE_RG_NAME" || -z "${DNS_ZONE_NAME}" ]]; then
    echo_stderr "DNS_ZONE_NAME and DNS_ZONE_RG_NAME are required. "
    exit 1
  fi

  if [ -z "$DNS_ADMIN_LABEL" ]; then
    echo_stderr "DNS_ADMIN_LABEL is required. "
    exit 1
  fi

  if [ -z "$DNS_CLUSTER_LABEL" ]; then
    echo_stderr "DNS_CLUSTER_LABEL is required. "
    exit 1
  fi

  if [ -z "$APPGW_ALIAS" ]; then
    echo_stderr "APPGW_ALIAS is required. "
    exit 1
  fi

  if [ -z "$USE_INTERNAL_LB" ]; then
    echo_stderr "USE_INTERNAL_LB is required. "
    exit 1
  fi

  if [ -z "$ENABLE_CUSTOM_SSL" ]; then
    echo_stderr "ENABLE_CUSTOM_SSL is required. "
    exit 1
  fi

  if [ -z "$ENABLE_COOKIE_BASED_AFFINITY" ]; then
    echo_stderr "ENABLE_COOKIE_BASED_AFFINITY is required. "
    exit 1
  fi

  if [ -z "$APPGW_FOR_REMOTE_CONSOLE" ]; then
    echo_stderr "APPGW_FOR_REMOTE_CONSOLE is required. "
    exit 1
  fi

  if [ -z "$DNS_ADMIN_T3_LABEL" ]; then
    echo_stderr "DNS_ADMIN_T3_LABEL is required. "
    exit 1
  fi

  if [ -z "$DNS_CLUSTER_T3_LABEL" ]; then
    echo_stderr "DNS_CLUSTER_T3_LABEL is required. "
    exit 1
  fi
}

function create_svc_lb() {
  # No lb svc inputs
  if [[ "${LB_SVC_VALUES}" != "[]" ]]; then
    chmod ugo+x $scriptDir/createLbSvc.sh
    bash $scriptDir/createLbSvc.sh
  fi
}

function create_appgw_ingress() {
  if [[ "${ENABLE_AGIC,,}" == "true" ]]; then
    chmod ugo+x $scriptDir/createAppGatewayIngress.sh
    bash $scriptDir/createAppGatewayIngress.sh
  fi
}

# Main script
set -Eeuo pipefail

export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

validate_input

install_utilities

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RG_NAME

create_svc_lb

create_appgw_ingress
