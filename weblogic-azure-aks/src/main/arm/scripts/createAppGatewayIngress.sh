# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description: to create Azure Application Gateway ingress for the following targets.
#   * [Optional] Admin console, with path host/console
#   * [Optional] Admin remote console, with path host/remoteconsole
#   * Cluster, with path host/*

echo "Script  ${0} starts"

function generate_appgw_cluster_config_file_expose_https() {
  clusterIngressHttpsName=${WLS_DOMAIN_UID}-cluster-appgw-ingress-https-svc
  clusterAppgwIngressHttpsYamlPath=${scriptDir}/appgw-cluster-ingress-https-svc.yaml
  cat <<EOF >${clusterAppgwIngressHttpsYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressHttpsName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constClusterName}"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "${APPGW_SSL_CERT_NAME}"
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: ${svcCluster}
              port:
                number: ${clusterTargetPort}
EOF
}

function generate_appgw_cluster_config_file_nossl() {
  clusterIngressName=${WLS_DOMAIN_UID}-cluster-appgw-ingress-svc
  clusterAppgwIngressYamlPath=${scriptDir}/appgw-cluster-ingress-svc.yaml
  cat <<EOF >${clusterAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constClusterName}"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: ${svcCluster}
              port:
                number: ${clusterTargetPort}
EOF
}

function generate_appgw_cluster_config_file_ssl() {
  clusterIngressName=${WLS_DOMAIN_UID}-cluster-appgw-ingress-svc
  clusterAppgwIngressYamlPath=${scriptDir}/appgw-cluster-ingress-svc.yaml
  cat <<EOF >${clusterAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constClusterName}"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "${APPGW_SSL_CERT_NAME}"
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
EOF
  if [[ "${ENABLE_DNS_CONFIGURATION,,}" == "true" ]]; then
    cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${DNS_CLUSTER_LABEL}.${DNS_ZONE_NAME}"
EOF
  else
    cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${APPGW_ALIAS}"
EOF
  fi

  cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${APPGW_TRUSTED_ROOT_CERT_NAME}"

spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: ${svcCluster}
              port:
                number: ${clusterTargetPort}
EOF
}

function generate_appgw_admin_config_file_nossl() {
  adminIngressName=${WLS_DOMAIN_UID}-admin-appgw-ingress-svc
  adminAppgwIngressYamlPath=${scriptDir}/appgw-admin-ingress-svc.yaml
  cat <<EOF >${adminAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constAdminServerName}"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /console*
          pathType: Prefix
          backend:
            service:
              name: ${svcAdminServer}
              port:
                number: ${adminTargetPort}
EOF
}

function generate_appgw_admin_remote_config_file_nossl() {
  cat <<EOF >${adminRemoteAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminRemoteIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constAdminServerName}-remote-console"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /remoteconsole*
          pathType: Prefix
          backend:
            service:
              name: ${svcAdminServer}
              port:
                number: ${adminTargetPort}
EOF
}

function generate_appgw_admin_config_file_ssl() {
  adminIngressName=${WLS_DOMAIN_UID}-admin-appgw-ingress-svc
  adminAppgwIngressYamlPath=${scriptDir}/appgw-admin-ingress-svc.yaml
  cat <<EOF >${adminAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constAdminServerName}"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "${APPGW_SSL_CERT_NAME}"
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
EOF

  if [[ "${ENABLE_DNS_CONFIGURATION,,}" == "true" ]]; then
    cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${DNS_ADMIN_LABEL}.${DNS_ZONE_NAME}"
EOF
  else
    cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${APPGW_ALIAS}"
EOF
  fi

  cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${APPGW_TRUSTED_ROOT_CERT_NAME}"

spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /console*
          pathType: Prefix
          backend:
            service:
              name: ${svcAdminServer}
              port:
                number: ${adminTargetPort}
EOF
}

function generate_appgw_admin_remote_config_file_ssl() {
  cat <<EOF >${adminRemoteAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminRemoteIngressName}
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"
    azure.weblogic.target: "${constAdminServerName}-remote-console"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "${APPGW_SSL_CERT_NAME}"
    appgw.ingress.kubernetes.io/use-private-ip: "${APPGW_USE_PRIVATE_IP}"
    appgw.ingress.kubernetes.io/cookie-based-affinity: "${ENABLE_COOKIE_BASED_AFFINITY}"
EOF

  if [[ "${ENABLE_DNS_CONFIGURATION,,}" == "true" ]]; then
    cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${DNS_ADMIN_LABEL}.${DNS_ZONE_NAME}"
EOF
  else
    cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${APPGW_ALIAS}"
EOF
  fi

  cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${APPGW_TRUSTED_ROOT_CERT_NAME}"

spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
        - path: /remoteconsole*
          pathType: Prefix
          backend:
            service:
              name: ${svcAdminServer}
              port:
                number: ${adminTargetPort}
EOF
}

function query_admin_target_port() {
  if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
    adminTargetPort=$(utility_query_service_port ${svcAdminServer} ${wlsDomainNS} 'internal-t3s')
  else
    adminTargetPort=$(utility_query_service_port ${svcAdminServer} ${wlsDomainNS} 'internal-t3')
  fi

  echo "Admin port of ${adminServerName}: ${adminTargetPort}"
}

# Create network peers for aks and appgw
function network_peers_aks_appgw() {
  # To successfully peer two virtual networks command 'az network vnet peering create' must be called twice with the values
  # for --vnet-name and --remote-vnet reversed.

  local aksMCRGName=$(az aks show -n $AKS_CLUSTER_NAME -g $AKS_CLUSTER_RG_NAME -o tsv --query "nodeResourceGroup")
  local ret=$(az group exists -n ${aksMCRGName})
  if [ "${ret,,}" == "false" ]; then
      echo_stderr "AKS namaged resource group ${aksMCRGName} does not exist."
      exit 1
  fi

  # query vnet from managed resource group
  local aksNetWorkId=$(az resource list -g ${aksMCRGName} --resource-type Microsoft.Network/virtualNetworks -o tsv --query '[*].id')

  # no vnet in managed resource group, then query vnet from aks agent
  if [ -z "${aksNetWorkId}" ]; then
    # assume all the agent pools are in the same vnet
    # e.g. /subscriptions/xxxx-xxxx-xxxx-xxxx/resourceGroups/foo-rg/providers/Microsoft.Network/virtualNetworks/foo-aks-vnet/subnets/default
    local aksAgent1Subnet=$(az aks show -n $AKS_CLUSTER_NAME -g $AKS_CLUSTER_RG_NAME | jq '.agentPoolProfiles[0] | .vnetSubnetId' | tr -d "\"")
    utility_validate_status "Get subnet id of aks agent 0."
    aksNetWorkId=${aksAgent1Subnet%\/subnets\/*}
  fi

  local aksNetworkName=${aksNetWorkId#*\/virtualNetworks\/}
  local aksNetworkRgName=${aksNetWorkId#*\/resourceGroups\/}
  local aksNetworkRgName=${aksNetworkRgName%\/providers\/*}

  local appGatewaySubnetId=$(az network application-gateway show -g ${CURRENT_RG_NAME} --name ${APPGW_NAME} -o tsv --query "gatewayIPConfigurations[0].subnet.id")
  local appGatewayVnetResourceGroup=$(az network application-gateway show -g ${CURRENT_RG_NAME} --name ${APPGW_NAME} -o tsv --query "gatewayIPConfigurations[0].subnet.resourceGroup")
  local appGatewaySubnetName=$(az resource show --ids ${appGatewaySubnetId} --query "name" -o tsv)
  local appgwNetworkId=$(echo $appGatewaySubnetId | sed s/"\/subnets\/${appGatewaySubnetName}"//)
  local appgwVnetName=$(az resource show --ids ${appgwNetworkId} --query "name" -o tsv)

  local toPeer=true
  # if the AKS and App Gateway have the same VNET, need not peer.
  if [ "${aksNetWorkId}" == "${appgwNetworkId}" ]; then
    echo_stdout "AKS and Application Gateway are in the same virtual network: ${appgwNetworkId}."
    toPeer=false
  fi

  # check if the Vnets have been peered.
  local ret=$(az network vnet peering list \
    --resource-group ${appGatewayVnetResourceGroup} \
    --vnet-name ${appgwVnetName} -o json |
    jq ".[] | select(.remoteVirtualNetwork.id==\"${aksNetWorkId}\")")
  if [ -n "$ret" ]; then
    echo_stdout "VNET of AKS ${aksNetWorkId} and Application Gateway ${appgwNetworkId} is peering."
    toPeer=false
  fi

  if [ "${toPeer}" == "true" ]; then
    az network vnet peering create \
      --name aks-appgw-peer \
      --remote-vnet ${aksNetWorkId} \
      --resource-group ${appGatewayVnetResourceGroup} \
      --vnet-name ${appgwVnetName} \
      --allow-vnet-access
    utility_validate_status "Create network peers for $aksNetWorkId and ${appgwNetworkId}."

    az network vnet peering create \
      --name aks-appgw-peer \
      --remote-vnet ${appgwNetworkId} \
      --resource-group ${aksNetworkRgName} \
      --vnet-name ${aksNetworkName} \
      --allow-vnet-access

    utility_validate_status "Complete creating network peers for $aksNetWorkId and ${appgwNetworkId}."
  fi

  # For kubenet network plugin: https://azure.github.io/application-gateway-kubernetes-ingress/how-tos/networking/#with-kubenet
  # find route table used by aks cluster
  local networkPlugin=$(az aks show -n $AKS_CLUSTER_NAME -g $AKS_CLUSTER_RG_NAME --query "networkProfile.networkPlugin" -o tsv)
  if [[ "${networkPlugin}" == "kubenet" ]]; then
    # the route table is in MC_ resource group
    routeTableId=$(az network route-table list -g $aksMCRGName --query "[].id | [0]" -o tsv)

    # associate the route table to Application Gateway's subnet
    az network vnet subnet update \
        --ids $appGatewaySubnetId \
        --route-table $routeTableId

    utility_validate_status "Associate the route table ${routeTableId} to Application Gateway's subnet ${appGatewaySubnetId}"
  fi
}

function query_cluster_target_port() {
  if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
    clusterTargetPort=$(utility_query_service_port ${svcCluster} ${wlsDomainNS} 'default-secure')
  else
    clusterTargetPort=$(utility_query_service_port ${svcCluster} ${wlsDomainNS} 'default')
  fi

  echo "Cluster port of ${clusterName}: ${clusterTargetPort}"
}

function generate_appgw_cluster_config_file() {
  if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
    generate_appgw_cluster_config_file_ssl
  else
    generate_appgw_cluster_config_file_nossl
    generate_appgw_cluster_config_file_expose_https
  fi
}

function generate_appgw_admin_config_file() {
  if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
    generate_appgw_admin_config_file_ssl
  else
    generate_appgw_admin_config_file_nossl
  fi
}

function generate_appgw_admin_remote_config_file() {
  if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
    generate_appgw_admin_remote_config_file_ssl
  else
    generate_appgw_admin_remote_config_file_nossl
  fi
}

# Currently, ingress controller does not have a tag that identifies it's ready to create ingress.
# This function is to create an ingress and check it's status. If the ingress is not available, then re-create it again.
function waitfor_agic_ready_and_create_ingress() {
  local svcName=$1
  local ymlFilePath=$2

  local ready=false
  local attempt=0
  while [[ "${ready}" == "false" && $attempt -lt ${checkAGICStatusMaxAttempt} ]]; do
    echo "Waiting for AGIC ready... ${attempt}"
    attempt=$((attempt + 1))
    kubectl apply -f ${ymlFilePath}

    # wait for the ingress ready, if the ingress is not available then delete it
    local svcAttempts=0
    local svcState="running"
    while [ "$svcState" == "running" ] && [ $svcAttempts -lt ${checkIngressStateMaxAttempt} ]; do
      svcAttempts=$((svcAttempts + 1))
      echo Waiting for job completed...${svcAttempts}
      sleep ${checkSVCInterval}

      ip=$(kubectl get ingress ${svcName} -n ${wlsDomainNS} -o json |
        jq '.status.loadBalancer.ingress[0].ip')
      echo "ip: ${ip}"
      if [[ "${ip}" != "null" ]]; then
        svcState="completed"
        ready=true
      fi
    done

    if [[ "${ready}" == "false" ]]; then
      kubectl delete -f ${ymlFilePath}
      sleep ${checkAGICStatusInterval}
    fi
  done

  if [ ${attempt} -ge ${checkAGICStatusMaxAttempt} ]; then
    echo_stderr "azure igress is not ready to create ingress. "
    exit 1
  fi

}

function appgw_ingress_svc_for_cluster() {
  # generate ingress svc config for cluster
  generate_appgw_cluster_config_file
  kubectl apply -f ${clusterAppgwIngressYamlPath}
  utility_validate_status "Create appgw ingress svc."
  waitfor_agic_ready_and_create_ingress \
    ${clusterIngressName} \
    ${clusterAppgwIngressYamlPath}

  # expose https for cluster if e2e ssl is not set up.
  if [[ "${ENABLE_CUSTOM_SSL,,}" != "true" ]]; then
    kubectl apply -f ${clusterAppgwIngressHttpsYamlPath}
    utility_validate_status "Create appgw ingress https svc."
    utility_waitfor_ingress_completed \
      ${clusterIngressHttpsName} \
      ${wlsDomainNS} \
      ${checkSVCStateMaxAttempt} \
      ${checkSVCInterval}
  fi
}

function appgw_ingress_svc_for_admin_server() {
  generate_appgw_admin_config_file
  kubectl apply -f ${adminAppgwIngressYamlPath}
  utility_validate_status "Create appgw ingress svc."
  utility_waitfor_ingress_completed \
    ${adminIngressName} \
    ${wlsDomainNS} \
    ${checkSVCStateMaxAttempt} \
    ${checkSVCInterval}
}

function appgw_ingress_svc_for_remote_console() {
  adminRemoteIngressName=${WLS_DOMAIN_UID}-admin-remote-appgw-ingress-svc
  adminRemoteAppgwIngressYamlPath=${scriptDir}/appgw-admin-remote-ingress-svc.yaml
  generate_appgw_admin_remote_config_file

  kubectl apply -f ${adminRemoteAppgwIngressYamlPath}
  utility_validate_status "Create appgw ingress svc."
  utility_waitfor_ingress_completed \
    ${adminRemoteIngressName} \
    ${wlsDomainNS} \
    ${checkSVCStateMaxAttempt} \
    ${checkSVCInterval}
}

function create_dns_record() {
  if [[ "${ENABLE_DNS_CONFIGURATION,,}" == "true" ]]; then
    create_dns_CNAME_record \
      ${APPGW_ALIAS} \
      ${DNS_CLUSTER_LABEL} \
      ${DNS_ZONE_RG_NAME} \
      ${DNS_ZONE_NAME}
  fi

  if [[ "${ENABLE_DNS_CONFIGURATION,,}" == "true" ]] &&
    [[ "${APPGW_FOR_ADMIN_SERVER,,}" == "true" ]]; then
    create_dns_CNAME_record \
      ${APPGW_ALIAS} \
      ${DNS_ADMIN_LABEL} \
      ${DNS_ZONE_RG_NAME} \
      ${DNS_ZONE_NAME}
  fi
}

function create_gateway_ingress() {
  # query admin server port used for non-ssl or ssl
  query_admin_target_port
  # query cluster port used for non-ssl or ssl
  query_cluster_target_port
  # create network peers between gateway vnet and aks vnet
  network_peers_aks_appgw

  # create ingress svc for cluster
  appgw_ingress_svc_for_cluster

  # create ingress svc for admin console
  if [[ "${APPGW_FOR_ADMIN_SERVER,,}" == "true" ]]; then
    appgw_ingress_svc_for_admin_server
  fi

  # create ingress svc for admin remote console
  if [[ "${APPGW_FOR_REMOTE_CONSOLE,,}" == "true" ]]; then
    appgw_ingress_svc_for_remote_console
  fi

  create_dns_record
}

# Initialize
script="${BASH_SOURCE[0]}"
scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh
source ${scriptDir}/createDnsRecord.sh

set -Eo pipefail

adminServerName=${constAdminServerName} # define in common.sh
azureAppgwIngressVersion="1.5.1"
clusterName=${constClusterName}
svcAdminServer="${WLS_DOMAIN_UID}-${adminServerName}"
svcCluster="${WLS_DOMAIN_UID}-cluster-${clusterName}"
wlsDomainNS="${WLS_DOMAIN_UID}-ns"

create_gateway_ingress
