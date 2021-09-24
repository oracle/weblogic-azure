# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description: to create Azure Application Gateway ingress for the following targets.
#   * [Optional] Admin console, with path host/console
#   * [Optional] Admin remote console, with path host/remoteconsole
#   * Cluster, with path host/*

echo "Script  ${0} starts"

# read <spBase64String> <appgwFrontendSSLCertPsw> from stdin
function read_sensitive_parameters_from_stdin() {
  read spBase64String appgwFrontendSSLCertPsw
}

function generate_appgw_cluster_config_file_expose_https() {
    clusterIngressHttpsName=${wlsDomainUID}-cluster-appgw-ingress-https-svc
    clusterAppgwIngressHttpsYamlPath=${scriptDir}/appgw-cluster-ingress-https-svc.yaml
    cat <<EOF >${clusterAppgwIngressHttpsYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressHttpsName}
  namespace: ${wlsDomainNS}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
EOF

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${clusterAppgwIngressHttpsYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${clusterAppgwIngressHttpsYamlPath}
spec:
  tls:
  - secretName: ${appgwFrontendSecretName}
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
    clusterIngressName=${wlsDomainUID}-cluster-appgw-ingress-svc
    clusterAppgwIngressYamlPath=${scriptDir}/appgw-cluster-ingress-svc.yaml
    cat <<EOF >${clusterAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressName}
  namespace: ${wlsDomainNS}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
EOF

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${clusterAppgwIngressYamlPath}
spec:
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
    clusterIngressName=${wlsDomainUID}-cluster-appgw-ingress-svc
    clusterAppgwIngressYamlPath=${scriptDir}/appgw-cluster-ingress-svc.yaml
    cat <<EOF >${clusterAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${clusterIngressName}
  namespace: ${wlsDomainNS}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
EOF
    if [[ "${enableCustomDNSAlias,,}" == "true" ]]; then
        cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${dnsClusterLabel}.${dnsZoneName}"
EOF
    else
        cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${appgwAlias}"
EOF
    fi

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${clusterAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${appgwBackendSecretName}"

spec:
  tls:
  - secretName: ${appgwFrontendSecretName}
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
    adminIngressName=${wlsDomainUID}-admin-appgw-ingress-svc
    adminAppgwIngressYamlPath=${scriptDir}/appgw-admin-ingress-svc.yaml
    cat <<EOF >${adminAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminIngressName}
  namespace: ${wlsDomainNS}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
EOF

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${adminAppgwIngressYamlPath}
spec:
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
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
EOF

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
spec:
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
    adminIngressName=${wlsDomainUID}-admin-appgw-ingress-svc
    adminAppgwIngressYamlPath=${scriptDir}/appgw-admin-ingress-svc.yaml
    cat <<EOF >${adminAppgwIngressYamlPath}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${adminIngressName}
  namespace: ${wlsDomainNS}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
EOF

    if [[ "${enableCustomDNSAlias,,}" == "true" ]]; then
        cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${dnsAdminLabel}.${dnsZoneName}"
EOF
    else
        cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${appgwAlias}"
EOF
    fi

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${adminAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${appgwBackendSecretName}"

spec:
  tls:
  - secretName: ${appgwFrontendSecretName}
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
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/backend-protocol: "https"
    
EOF

    if [[ "${enableCustomDNSAlias,,}" == "true" ]]; then
        cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${dnsAdminLabel}.${dnsZoneName}"
EOF
    else
        cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/backend-hostname: "${appgwAlias}"
EOF
    fi

    if [[ "${enableCookieBasedAffinity,,}" == "true" ]]; then
        cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/cookie-based-affinity: "true"
EOF
    fi

    cat <<EOF >>${adminRemoteAppgwIngressYamlPath}
    appgw.ingress.kubernetes.io/appgw-trusted-root-certificate: "${appgwBackendSecretName}"

spec:
  tls:
  - secretName: ${appgwFrontendSecretName}
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
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        adminTargetPort=$(utility_query_service_port ${svcAdminServer} ${wlsDomainNS} 'default-secure')
    else
        adminTargetPort=$(utility_query_service_port ${svcAdminServer} ${wlsDomainNS} 'default')
    fi

    echo "Admin port of ${adminServerName}: ${adminTargetPort}"
}

# Create network peers for aks and appgw
function network_peers_aks_appgw() {
    # To successfully peer two virtual networks command 'az network vnet peering create' must be called twice with the values
    # for --vnet-name and --remote-vnet reversed.
    aksMCRGName=$(az aks show -n $aksClusterName -g $aksClusterRGName -o tsv --query "nodeResourceGroup")
    ret=$(az group exists -n ${aksMCRGName})
    if [ "${ret,,}" == "false" ]; then
        echo_stderr "AKS namaged resource group ${aksMCRGName} does not exist."
        exit 1
    fi

    aksNetWorkId=$(az resource list -g ${aksMCRGName} --resource-type Microsoft.Network/virtualNetworks -o tsv --query '[*].id')
    aksNetworkName=$(az resource list -g ${aksMCRGName} --resource-type Microsoft.Network/virtualNetworks -o tsv --query '[*].name')
    az network vnet peering create \
        --name aks-appgw-peer \
        --remote-vnet ${aksNetWorkId} \
        --resource-group ${curRGName} \
        --vnet-name ${vnetName} \
        --allow-vnet-access
    utility_validate_status "Create network peers for $aksNetWorkId and ${vnetName}."

    appgwNetworkId=$(az resource list -g ${curRGName} --name ${vnetName} -o tsv --query '[*].id')
    az network vnet peering create \
        --name aks-appgw-peer \
        --remote-vnet ${appgwNetworkId} \
        --resource-group ${aksMCRGName} \
        --vnet-name ${aksNetworkName} \
        --allow-vnet-access

    utility_validate_status "Create network peers for $aksNetWorkId and ${vnetName}."

    # For Kbectl network plugin: https://azure.github.io/application-gateway-kubernetes-ingress/how-tos/networking/#with-kubenet
    # find route table used by aks cluster
    routeTableId=$(az network route-table list -g $aksMCRGName --query "[].id | [0]" -o tsv)

    # get the application gateway's subnet
    appGatewaySubnetId=$(az network application-gateway show -n $appgwName -g $curRGName -o tsv --query "gatewayIpConfigurations[0].subnet.id")

    # associate the route table to Application Gateway's subnet
    az network vnet subnet update \
        --ids $appGatewaySubnetId \
        --route-table $routeTableId

    utility_validate_status "Associate the route table ${routeTableId} to Application Gateway's subnet ${appGatewaySubnetId}"
}

function query_cluster_target_port() {
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        clusterTargetPort=$(utility_query_service_port ${svcCluster} ${wlsDomainNS} 'default-secure')
    else
        clusterTargetPort=$(utility_query_service_port ${svcCluster} ${wlsDomainNS} 'default')
    fi

    echo "Cluster port of ${clusterName}: ${clusterTargetPort}"
}

function install_azure_ingress() {
    # create sa and bind cluster-admin role
    # grant azure ingress permission to access WebLogic service
    kubectl apply -f ${scriptDir}/appgw-ingress-clusterAdmin-roleBinding.yaml

    install_helm
    helm repo add application-gateway-kubernetes-ingress ${appgwIngressHelmRepo}
    helm repo update

    # generate Helm config for azure ingress
    customAppgwHelmConfig=${scriptDir}/appgw-helm-config.yaml
    cp ${scriptDir}/appgw-helm-config.yaml.template ${customAppgwHelmConfig}
    subID=${subID#*\/subscriptions\/}
    sed -i -e "s:@SUB_ID@:${subID}:g" ${customAppgwHelmConfig}
    sed -i -e "s:@APPGW_RG_NAME@:${curRGName}:g" ${customAppgwHelmConfig}
    sed -i -e "s:@APPGW_NAME@:${appgwName}:g" ${customAppgwHelmConfig}
    sed -i -e "s:@WATCH_NAMESPACE@:${wlsDomainNS}:g" ${customAppgwHelmConfig}
    sed -i -e "s:@SP_ENCODING_CREDENTIALS@:${spBase64String}:g" ${customAppgwHelmConfig}

    helm install ingress-azure \
        -f ${customAppgwHelmConfig} \
        application-gateway-kubernetes-ingress/ingress-azure \
        --version ${azureAppgwIngressVersion}

    utility_validate_status "Install app gateway ingress controller."

    attempts=0
    podState="running"
    while [ "$podState" == "running" ] && [ $attempts -lt ${checkPodStatusMaxAttemps} ]; do
        podState="completed"
        attempts=$((attempts + 1))
        echo Waiting for Pod running...${attempts}
        sleep ${checkPodStatusInterval}

        ret=$(kubectl get pod -o json |
            jq '.items[] | .status.containerStatuses[] | select(.name=="ingress-azure") | .ready')
        if [[ "${ret}" == "false" ]]; then
            podState="running"
        fi
    done

    if [ "$podState" == "running" ] && [ $attempts -ge ${checkPodStatusMaxAttemps} ]; then
        echo_stderr "Failed to install app gateway ingress controller."
        exit 1
    fi
}

function output_create_gateway_ssl_k8s_secret() {
    echo "export gateway frontend certificates"
    echo "$appgwFrontendSSLCertData" | base64 -d >${scriptDir}/$appgwFrontCertFileName

    appgwFrontendSSLCertPassin=${appgwFrontendSSLCertPsw}
    if [[ "$appgwCertificateOption" == "${appgwSelfsignedCert}" ]]; then
        appgwFrontendSSLCertPassin="" # empty password
    fi

    openssl pkcs12 \
        -in ${scriptDir}/$appgwFrontCertFileName \
        -nocerts \
        -out ${scriptDir}/$appgwFrontCertKeyFileName \
        -passin pass:${appgwFrontendSSLCertPassin} \
        -passout pass:${appgwFrontendSSLCertPsw}

    utility_validate_status "Export key from frontend certificate."

    openssl rsa -in ${scriptDir}/$appgwFrontCertKeyFileName \
        -out ${scriptDir}/$appgwFrontCertKeyDecrytedFileName \
        -passin pass:${appgwFrontendSSLCertPsw}

    utility_validate_status "Decryte private key."

    openssl pkcs12 \
        -in ${scriptDir}/$appgwFrontCertFileName \
        -clcerts \
        -nokeys \
        -out ${scriptDir}/$appgwFrontPublicCertFileName \
        -passin pass:${appgwFrontendSSLCertPassin}

    utility_validate_status "Export cert from frontend certificate."

    echo "create k8s tsl secret for app gateway frontend ssl termination"
    kubectl -n ${wlsDomainNS} create secret tls ${appgwFrontendSecretName} \
        --key="${scriptDir}/$appgwFrontCertKeyDecrytedFileName" \
        --cert="${scriptDir}/$appgwFrontPublicCertFileName"

    utility_validate_status "create k8s tsl secret for app gateway frontend ssl termination."
}

function validate_backend_ca_cert() {
    az network application-gateway root-cert list \
        --gateway-name $appgwName \
        --resource-group $curRGName |
        jq '.[] | .name' | grep "${appgwBackendSecretName}"

    utility_validate_status "check if backend cert exists."
}

function generate_appgw_cluster_config_file() {
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        generate_appgw_cluster_config_file_ssl
    else
        generate_appgw_cluster_config_file_nossl
        generate_appgw_cluster_config_file_expose_https
    fi
}

function generate_appgw_admin_config_file() {
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        generate_appgw_admin_config_file_ssl
    else
        generate_appgw_admin_config_file_nossl
    fi
}

function generate_appgw_admin_remote_config_file() {
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        generate_appgw_admin_remote_config_file_ssl
    else
        generate_appgw_admin_remote_config_file_nossl
    fi
}

function appgw_ingress_svc_for_cluster() {
    # generate ingress svc config for cluster
    generate_appgw_cluster_config_file
    kubectl apply -f ${clusterAppgwIngressYamlPath}
    utility_validate_status "Create appgw ingress svc."
    utility_waitfor_ingress_completed \
        ${clusterIngressName} \
        ${wlsDomainNS} \
        ${checkSVCStateMaxAttempt} \
        ${checkSVCInterval}

    # expose https for cluster if e2e ssl is not set up.
    if [[ "${enableCustomSSL,,}" != "true" ]]; then
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
    utility_waitfor_lb_svc_completed \
        ${adminIngressName} \
        ${wlsDomainNS} \
        ${checkSVCStateMaxAttempt} \
        ${checkSVCInterval}
}

function appgw_ingress_svc_for_remote_console() {
    adminRemoteIngressName=${wlsDomainUID}-admin-remote-appgw-ingress-svc
    adminRemoteAppgwIngressYamlPath=${scriptDir}/appgw-admin-remote-ingress-svc.yaml
    generate_appgw_admin_remote_config_file

    kubectl apply -f ${adminRemoteAppgwIngressYamlPath}
    utility_validate_status "Create appgw ingress svc."
    utility_waitfor_lb_svc_completed \
        ${adminRemoteIngressName} \
        ${wlsDomainNS} \
        ${checkSVCStateMaxAttempt} \
        ${checkSVCInterval}
}

function create_dns_record() {
    if [[ "${enableCustomDNSAlias,,}" == "true" ]]; then
        create_dns_CNAME_record \
            ${appgwAlias} \
            ${dnsClusterLabel} \
            ${dnsRGName} \
            ${dnsZoneName}
    fi

    if [[ "${enableCustomDNSAlias,,}" == "true" ]] &&
        [[ "${appgwForAdminServer,,}" == "true" ]]; then
        create_dns_CNAME_record \
            ${appgwAlias} \
            ${dnsAdminLabel} \
            ${dnsRGName} \
            ${dnsZoneName}
    fi
}

function create_gateway_ingress() {
    # query admin server port used for non-ssl or ssl
    query_admin_target_port
    # query cluster port used for non-ssl or ssl
    query_cluster_target_port
    # create network peers between gateway vnet and aks vnet
    network_peers_aks_appgw
    # install azure ingress controllor
    install_azure_ingress
    # create tsl/ssl frontend secrets
    output_create_gateway_ssl_k8s_secret

    # validate backend CA certificate
    # the certificate has been upload to Application Gateway in
    # weblogic-azure-aks\src\main\bicep\modules\networking.bicep
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
        validate_backend_ca_cert
    fi

    # create ingress svc for cluster
    appgw_ingress_svc_for_cluster

    # create ingress svc for admin console
    if [[ "${appgwForAdminServer,,}" == "true" ]]; then
        appgw_ingress_svc_for_admin_server
    fi

    # create ingress svc for admin remote console
    if [[ "${enableRemoteConsole,,}" == "true" ]]; then
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

aksClusterRGName=$1
aksClusterName=$2
wlsDomainUID=$3
subID=$4
curRGName=$5
appgwName=$6
vnetName=$7
appgwForAdminServer=$8
enableCustomDNSAlias=$9
dnsRGName=${10}
dnsZoneName=${11}
dnsAdminLabel=${12}
dnsClusterLabel=${13}
appgwAlias=${14}
appgwFrontendSSLCertData=${15}
appgwCertificateOption=${16}
enableCustomSSL=${17}
enableCookieBasedAffinity=${18}
enableRemoteConsole=${19}

adminServerName=${constAdminServerName} # define in common.sh
appgwIngressHelmRepo="https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/"
appgwFrontCertFileName="appgw-frontend-cert.pfx"
appgwFrontCertKeyDecrytedFileName="appgw-frontend-cert.key"
appgwFrontCertKeyFileName="appgw-frontend-cert-decryted.key"
appgwFrontPublicCertFileName="appgw-frontend-cert.crt"
appgwFrontendSecretName="frontend-tls"
appgwBackendSecretName="backend-tls"
appgwSelfsignedCert="generateCert"
azureAppgwIngressVersion="1.4.0"
clusterName=${constClusterName}
httpsListenerName="myHttpsListenerName$(date +%s)"
httpsRuleName="myHttpsRule$(date +%s)"
svcAdminServer="${wlsDomainUID}-${adminServerName}"
svcCluster="${wlsDomainUID}-cluster-${clusterName}"
wlsDomainNS="${wlsDomainUID}-ns"

read_sensitive_parameters_from_stdin

create_gateway_ingress
