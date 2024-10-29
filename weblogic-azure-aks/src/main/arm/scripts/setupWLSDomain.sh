# Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
# env inputs:
# URL_3RD_DATASOURCE
# ORACLE_ACCOUNT_ENTITLED

echo "Script ${0} starts"

#Function to display usage message
function usage() {
    usage=$(
        cat <<-END
Specify the following ENV variables:
ACR_NAME
AKS_CLUSTER_NAME
AKS_CLUSTER_RESOURCEGROUP_NAME
CURRENT_RESOURCEGROUP_NAME
ENABLE_ADMIN_CUSTOM_T3
ENABLE_CLUSTER_CUSTOM_T3
ENABLE_CUSTOM_SSL
ENABLE_PV
ORACLE_ACCOUNT_NAME
ORACLE_ACCOUNT_PASSWORD
ORACLE_ACCOUNT_ENTITLED
SCRIPT_LOCATION
STORAGE_ACCOUNT_NAME
URL_3RD_DATASOURCE
USE_ORACLE_IMAGE
USER_PROVIDED_IMAGE_PATH
WLS_DOMAIN_NAME
WLS_DOMAIN_UID
WLS_ADMIN_PASSWORD
WLS_ADMIN_USER_NAME
WLS_APP_PACKAGE_URLS
WLS_APP_REPLICAS
WLS_CLUSTER_SIZE
WLS_IMAGE_TAG
WLS_JAVA_OPTIONS
WLS_MANAGED_SERVER_PREFIX
WLS_RESOURCE_REQUEST_CPU
WLS_RESOURCE_REQUEST_MEMORY
WLS_SSL_IDENTITY_DATA
WLS_SSL_IDENTITY_PASSWORD
WLS_SSL_IDENTITY_TYPE
WLS_SSL_TRUST_DATA
WLS_SSL_TRUST_PASSWORD
WLS_SSL_TRUST_TYPE
WLS_SSL_PRIVATE_KEY_ALIAS
WLS_SSL_PRIVATE_KEY_PASSWORD
WLS_T3_ADMIN_PORT
WLS_T3_CLUSTER_PORT
WLS_WDT_RUNTIME_PSW
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
    if [ -z "$USE_ORACLE_IMAGE" ]; then
        echo_stderr "USER_PROVIDED_IMAGE_PATH is required. "
        usage 1
    fi

    if [[ "${USE_ORACLE_IMAGE,,}" == "${constTrue}" ]] && [[ -z "$ORACLE_ACCOUNT_NAME" || -z "${ORACLE_ACCOUNT_PASSWORD}" ]]; then
        echo_stderr "Oracle SSO account is required. "
        usage 1
    fi

    if [[ -z "$AKS_CLUSTER_RESOURCEGROUP_NAME" || -z "${AKS_CLUSTER_NAME}" ]]; then
        echo_stderr "AKS cluster name and resource group name are required. "
        usage 1
    fi

    if [ -z "$WLS_IMAGE_TAG" ]; then
        echo_stderr "WLS_IMAGE_TAG is required. "
        usage 1
    fi

    if [ -z "$ACR_NAME" ]; then
        echo_stderr "ACR_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_DOMAIN_NAME" ]; then
        echo_stderr "WLS_DOMAIN_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_DOMAIN_UID" ]; then
        echo_stderr "WLS_DOMAIN_UID is required. "
        usage 1
    fi

    if [ -z "$WLS_ADMIN_USER_NAME" ]; then
        echo_stderr "WLS_ADMIN_USER_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_ADMIN_PASSWORD" ]; then
        echo_stderr "WLS_ADMIN_PASSWORD is required. "
        usage 1
    fi

    if [ -z "$WLS_WDT_RUNTIME_PSW" ]; then
        echo_stderr "WLS_WDT_RUNTIME_PSW is required. "
        usage 1
    fi

    if [ -z "$WLS_RESOURCE_REQUEST_CPU" ]; then
        echo_stderr "WLS_RESOURCE_REQUEST_CPU is required. "
        usage 1
    fi

    if [ -z "$WLS_RESOURCE_REQUEST_MEMORY" ]; then
        echo_stderr "WLS_RESOURCE_REQUEST_MEMORY is required. "
        usage 1
    fi

    if [ -z "$WLS_MANAGED_SERVER_PREFIX" ]; then
        echo_stderr "WLS_MANAGED_SERVER_PREFIX is required. "
        usage 1
    fi

    if [ -z "$WLS_APP_REPLICAS" ]; then
        echo_stderr "WLS_APP_REPLICAS is required. "
        usage 1
    fi

    if [ -z "$WLS_APP_PACKAGE_URLS" ]; then
        echo_stderr "WLS_APP_PACKAGE_URLS is required. "
        usage 1
    fi

    if [ -z "$CURRENT_RESOURCEGROUP_NAME" ]; then
        echo_stderr "CURRENT_RESOURCEGROUP_NAME is required. "
        usage 1
    fi

    if [ -z "$SCRIPT_LOCATION" ]; then
        echo_stderr "SCRIPT_LOCATION is required. "
        usage 1
    fi

    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
        echo_stderr "STORAGE_ACCOUNT_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_CLUSTER_SIZE" ]; then
        echo_stderr "WLS_CLUSTER_SIZE is required. "
        usage 1
    fi

    if [ -z "$ENABLE_CUSTOM_SSL" ]; then
        echo_stderr "ENABLE_CUSTOM_SSL is required. "
        usage 1
    fi

    if [[ -z "$WLS_SSL_IDENTITY_DATA" || -z "${WLS_SSL_IDENTITY_PASSWORD}" ]]; then
        echo_stderr "WLS_SSL_IDENTITY_PASSWORD and WLS_SSL_IDENTITY_DATA are required. "
        usage 1
    fi

    if [ -z "$WLS_SSL_IDENTITY_TYPE" ]; then
        echo_stderr "WLS_SSL_IDENTITY_TYPE is required. "
        usage 1
    fi

    if [[ -z "$WLS_SSL_PRIVATE_KEY_ALIAS" || -z "${WLS_SSL_PRIVATE_KEY_PASSWORD}" ]]; then
        echo_stderr "WLS_SSL_PRIVATE_KEY_ALIAS and WLS_SSL_PRIVATE_KEY_PASSWORD are required. "
        usage 1
    fi

    if [[ -z "$WLS_SSL_TRUST_DATA" || -z "${WLS_SSL_TRUST_PASSWORD}" ]]; then
        echo_stderr "WLS_SSL_TRUST_DATA and WLS_SSL_TRUST_PASSWORD are required. "
        usage 1
    fi

    if [ -z "$WLS_SSL_TRUST_TYPE" ]; then
        echo_stderr "WLS_SSL_TRUST_TYPE is required. "
        usage 1
    fi

    if [ -z "$ENABLE_PV" ]; then
        echo_stderr "ENABLE_PV is required. "
        usage 1
    fi

    if [ -z "$ENABLE_ADMIN_CUSTOM_T3" ]; then
        echo_stderr "ENABLE_ADMIN_CUSTOM_T3 is required. "
        usage 1
    fi

    if [ -z "$ENABLE_CLUSTER_CUSTOM_T3" ]; then
        echo_stderr "ENABLE_CLUSTER_CUSTOM_T3 is required. "
        usage 1
    fi

    if [ -z "$WLS_T3_ADMIN_PORT" ]; then
        echo_stderr "WLS_T3_ADMIN_PORT is required. "
        usage 1
    fi

    if [ -z "$WLS_T3_CLUSTER_PORT" ]; then
        echo_stderr "WLS_T3_CLUSTER_PORT is required. "
        usage 1
    fi

    if [ -z "$WLS_JAVA_OPTIONS" ]; then
        echo_stderr "WLS_JAVA_OPTIONS is required. "
        usage 1
    fi

    if [[ "${WLS_JAVA_OPTIONS}" == "null" ]];then
        WLS_JAVA_OPTIONS=""
    fi

    if [[ "${USE_ORACLE_IMAGE,,}" == "${constFalse}" ]] && [ -z "$USER_PROVIDED_IMAGE_PATH" ]; then
        echo_stderr "USER_PROVIDED_IMAGE_PATH is required. "
        usage 1
    fi
}

# Validate teminal status with $?, exit with exception if errors happen.
function validate_status() {
    if [ $? == 1 ]; then
        echo_stderr "$@"
        echo_stderr "Errors happen, exit 1."
        exit 1
    else
        echo_stdout "$@"
    fi
}

function get_wls_operator_version() {
    local wlsToolingFamilyJsonFile=weblogic_tooling_family.json
    # download the json file that wls operator version from weblogic-azure repo.
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fsL "${gitUrl4WLSToolingFamilyJsonFile}" -o ${wlsToolingFamilyJsonFile}
    if [ $? -eq 0 ]; then
        wlsOptVersion=$(cat ${wlsToolingFamilyJsonFile} | jq  ".items[] | select(.key==\"WKO\") | .version" | tr -d "\"")
        echo "WKO version: ${wlsOptVersion}"
    else
        echo "WKO version: latest"
    fi
}

# Install latest kubectl and Helm
function install_utilities() {
    if [ -d "apps" ]; then
        rm apps -f -r
    fi

    mkdir apps
    cd apps

    # Install kubectl
    az aks install-cli
    echo "kubectl version"
    ret=$(kubectl --help)
    validate_status ${ret}

    # Install Helm
    browserURL=$(curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -s https://api.github.com/repos/helm/helm/releases/latest |
        grep "browser_download_url.*linux-amd64.tar.gz.asc" |
        cut -d : -f 2,3 |
        tr -d \")
    helmLatestVersion=${browserURL#*download\/}
    helmLatestVersion=${helmLatestVersion%%\/helm*}
    helmPackageName=helm-${helmLatestVersion}-linux-amd64.tar.gz
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fL https://get.helm.sh/${helmPackageName} -o /tmp/${helmPackageName}
    tar -zxvf /tmp/${helmPackageName} -C /tmp
    mv /tmp/linux-amd64/helm /usr/local/bin/helm
    echo "Helm version"
    helm version
    validate_status "Finished installing Helm."

    echo "az cli version"
    ret=$(az --version)
    validate_status ${ret}
}

# remove the operator if it is not running.
function uninstall_operator() {
    echo "remove operator"
    helm uninstall ${operatorName} -n ${wlsOptNameSpace}
    attempts=0
    ret=$(helm list -n ${wlsOptNameSpace} | grep "${operatorName}")
    while [ -n "$ret" ] && [ $attempts -lt ${optUninstallMaxTry} ]; do
        sleep ${optUninstallInterval}
        attempts=$((attempts + 1))
        ret=$(helm list -n ${wlsOptNameSpace} | grep "${operatorName}")
    done

    if [ $attempts -ge ${optUninstallMaxTry} ]; then
        echo_stderr "Failed to remove an unvaliable operator."
        exit 1
    fi
}

function validate_existing_operator() {
    ret=$(helm list -n ${wlsOptNameSpace} | grep "${operatorName}" | grep "deployed")
    if [ -n "${ret}" ]; then
        echo "the operator has been deployed"
        echo "${ret}"

        ret=$(kubectl get pod -n ${wlsOptNameSpace} | grep "Running" | grep "1/1")
        if [ -n "${ret}" ]; then
            echo "the operator is ready to use."
            operatorStatus=${constTrue}
        else
            echo "the operator is unavailable."
            uninstall_operator
        fi
    fi
}

# Install WebLogic operator using charts from GitHub Repo
# * Create namespace weblogic-operator-ns
# * Create service account
# * install operator
function install_wls_operator() {
    echo "check if the operator is installed"
    ret=$(kubectl get namespace | grep "${wlsOptNameSpace}")
    if [ -z "${ret}" ]; then
        echo "create namespace ${wlsOptNameSpace}"
        kubectl create namespace ${wlsOptNameSpace}
        kubectl -n ${wlsOptNameSpace} create serviceaccount ${wlsOptSA}

        helm repo add ${wlsOptRelease} ${wlsOptHelmChart} --force-update
        ret=$(helm repo list)
        validate_status ${ret}
    else
        export operatorStatus=${constFalse}
        validate_existing_operator
        if [[ "${operatorStatus}" == "${constTrue}" ]]; then
            return
        fi
    fi

    echo "install the operator"
    if [[ -n "${wlsOptVersion}" ]]; then
        helm install ${wlsOptRelease} weblogic-operator/weblogic-operator \
            --namespace ${wlsOptNameSpace} \
            --set serviceAccount=${wlsOptSA} \
            --set "enableClusterRoleBinding=true" \
            --set "domainNamespaceSelectionStrategy=LabelSelector" \
            --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
            --version ${wlsOptVersion} \
            --wait
    else
        helm install ${wlsOptRelease} weblogic-operator/weblogic-operator \
        --namespace ${wlsOptNameSpace} \
        --set serviceAccount=${wlsOptSA} \
        --set "enableClusterRoleBinding=true" \
        --set "domainNamespaceSelectionStrategy=LabelSelector" \
        --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
        --wait
    fi

    validate_status "Installing WLS operator."

    # valiadate weblogic operator
    ret=$(kubectl get pod -n ${wlsOptNameSpace} | grep "Running" | grep "1/1")
    if [ -z "$ret" ]; then
        echo_stderr "No WebLogic operator is running."
        exit 1
    fi
}

# Query ACR login server, username, password
function query_acr_credentials() {
    # to mitigate error in https://learn.microsoft.com/en-us/answers/questions/1188413/the-resource-with-name-name-and-type-microsoft-con
    az provider register -n Microsoft.ContainerRegistry
    
    ACR_LOGIN_SERVER=$(az acr show -n $ACR_NAME -g ${ACR_RESOURCEGROUP_NAME} --query 'loginServer' -o tsv)
    validate_status ${ACR_LOGIN_SERVER}
    
    ACR_USER_NAME=$(az acr credential show -n $ACR_NAME -g ${ACR_RESOURCEGROUP_NAME} --query 'username' -o tsv)
    validate_status "Query ACR credentials."

    ACR_PASSWORD=$(az acr credential show -n $ACR_NAME -g ${ACR_RESOURCEGROUP_NAME} --query 'passwords[0].value' -o tsv)
    validate_status "Query ACR credentials."
}

# Build docker image
#  * Create Ubuntu machine VM-UBUNTU
#  * Running vm extension to run buildWLSDockerImage.sh, the script will:
#    * build a docker image with domain model, applications based on specified WebLogic Standard image
#    * push the image to ACR
function build_docker_image() {
    echo "build a new image including the new applications"
    chmod ugo+x $scriptDir/createVMAndBuildImage.sh
    echo ${ACR_PASSWORD} | bash $scriptDir/createVMAndBuildImage.sh $newImageTag ${ACR_LOGIN_SERVER} ${ACR_USER_NAME}

    # to mitigate error in https://learn.microsoft.com/en-us/answers/questions/1188413/the-resource-with-name-name-and-type-microsoft-con
    az provider register -n Microsoft.ContainerRegistry

    az acr repository show -n ${ACR_NAME} --image aks-wls-images:${newImageTag}
    if [ $? -ne 0 ]; then
        echo "Failed to create image ${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}"
        exit 1
    fi
}

function create_source_folder_for_certificates() {
    mntRoot="/wls"
    mntPath="$mntRoot/$STORAGE_ACCOUNT_NAME/$azFileShareName"

    mkdir -p $mntPath

    # Create a folder for certificates
    securityDir=${mntPath}/security
    if [ ! -d "${securityDir}" ]; then
        mkdir ${mntPath}/security
    else
        rm -f ${mntPath}/$wlsIdentityKeyStoreFileName
        rm -f ${mntPath}/$wlsTrustKeyStoreFileName
        rm -f ${mntPath}/${wlsTrustKeyStoreJKSFileName}
    fi
}

function validate_ssl_keystores() {
    #validate if trust keystore has entry
    ${JAVA_HOME}/bin/keytool -list -v \
        -keystore ${mntPath}/${wlsTrustKeyStoreJKSFileName} \
        -storepass $WLS_SSL_TRUST_PASSWORD \
        -storetype jks |
        grep 'Entry type:' |
        grep 'trustedCertEntry'

    validate_status "validate Trust Keystore."

    echo "Validate SSL key stores successfull !!"
}

function upload_certificates_to_fileshare() {
    expiryData=$(($(date +%s) + ${sasTokenValidTime}))
    sasTokenEnd=$(date -d@"$expiryData" -u '+%Y-%m-%dT%H:%MZ')
    sasToken=$(az storage share generate-sas \
        --name ${azFileShareName} \
        --account-name ${STORAGE_ACCOUNT_NAME} \
        --https-only \
        --permissions dlrw \
        --expiry $sasTokenEnd -o tsv)

    echo "create directory security"
    fsSecurityDirName="security"
    utility_create_directory_to_fileshare \
        ${fsSecurityDirName} \
        ${azFileShareName} \
        ${STORAGE_ACCOUNT_NAME} \
        $sasToken

    echo "upload $wlsIdentityKeyStoreFileName"
    utility_upload_file_to_fileshare \
        ${azFileShareName} \
        ${STORAGE_ACCOUNT_NAME} \
        "$wlsIdentityKeyStoreFileName" \
        ${mntPath}/$wlsIdentityKeyStoreFileName \
        $sasToken

    echo "upload $wlsTrustKeyStoreFileName"
    utility_upload_file_to_fileshare \
        ${azFileShareName} \
        ${STORAGE_ACCOUNT_NAME} \
        "$wlsTrustKeyStoreFileName" \
        ${mntPath}/$wlsTrustKeyStoreFileName \
        $sasToken

    echo "upload $wlsTrustKeyStoreJKSFileName"
    utility_upload_file_to_fileshare \
        ${azFileShareName} \
        ${STORAGE_ACCOUNT_NAME} \
        "$wlsTrustKeyStoreJKSFileName" \
        ${mntPath}/${wlsTrustKeyStoreJKSFileName} \
        $sasToken
}

function output_ssl_keystore() {
    echo "Custom SSL is enabled. Storing CertInfo as files..."
    #decode cert data once again as it would got base64 encoded
    echo "$WLS_SSL_IDENTITY_DATA" | base64 -d >${mntPath}/$wlsIdentityKeyStoreFileName
    echo "$WLS_SSL_TRUST_DATA" | base64 -d >${mntPath}/$wlsTrustKeyStoreFileName

    # export jks file
    # -Dweblogic.security.SSL.trustedCAKeyStorePassPhrase for PKCS12 is not working correctly
    # we neet to convert PKCS12 file to JKS file and specify in domain.yaml via -Dweblogic.security.SSL.trustedCAKeyStore
    if [[ "${WLS_SSL_TRUST_TYPE,,}" != "jks" ]]; then
        ${JAVA_HOME}/bin/keytool -importkeystore \
            -srckeystore ${mntPath}/${wlsTrustKeyStoreFileName} \
            -srcstoretype ${WLS_SSL_TRUST_TYPE} \
            -srcstorepass ${WLS_SSL_TRUST_PASSWORD} \
            -destkeystore ${mntPath}/${wlsTrustKeyStoreJKSFileName} \
            -deststoretype jks \
            -deststorepass ${WLS_SSL_TRUST_PASSWORD}

        validate_status "Export trust JKS file."
    else
        echo "$WLS_SSL_TRUST_DATA" | base64 -d >${mntPath}/${wlsTrustKeyStoreJKSFileName}
    fi
}

# Create storage for AKS cluster
# * Create secret for storage account
# * Create PV using Azure file share
# * Create PVC
function create_pv() {
    echo "check if pv/pvc have been created."
    pvcName=${WLS_DOMAIN_UID}-pvc-azurefile
    pvName=${WLS_DOMAIN_UID}-pv-azurefile
    ret=$(kubectl -n ${wlsDomainNS} get pvc ${pvcName} | grep "Bound")

    if [ -n "$ret" ]; then
        echo "pvc is bound to namespace ${wlsDomainNS}."
        # this is a workaround for update domain using marketplace offer.
        # the offer will create a new storage account in a new resource group.
        # remove the new storage account.
        currentStorageAccount=$(kubectl get pv ${pvName} -o json | jq '. | .metadata.labels.storageAccount' | tr -d "\"")
        if [[ "${currentStorageAccount}" != "${STORAGE_ACCOUNT_NAME}" ]]; then
            echo "the cluster is bound to pv on storage account ${currentStorageAccount}"
            az storage account delete -n ${STORAGE_ACCOUNT_NAME} -g $CURRENT_RESOURCEGROUP_NAME -y
            STORAGE_ACCOUNT_NAME=${currentStorageAccount} # update storage account name
            echo "query storage account resource group"
            storageResourceGroup=$(az storage account show --name ${STORAGE_ACCOUNT_NAME} | jq '.resourceGroup' | tr -d "\"")
            echo "resource group that contains storage account ${STORAGE_ACCOUNT_NAME} is ${storageResourceGroup}"
        fi

        return
    fi

    echo "create pv/pvc."
    export storageAccountKey=$(az storage account keys list --resource-group $storageResourceGroup --account-name $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
    export azureSecretName="azure-secret"
    kubectl -n ${wlsDomainNS} create secret generic ${azureSecretName} \
        --from-literal=azurestorageaccountname=${STORAGE_ACCOUNT_NAME} \
        --from-literal=azurestorageaccountkey=${storageAccountKey}

    # generate pv configurations
    customPVYaml=${scriptDir}/pv.yaml
    cp ${scriptDir}/pv.yaml.template ${customPVYaml}
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVYaml}
    sed -i -e "s:@PV_NAME@:${pvName}:g" ${customPVYaml}
    sed -i -e "s:@PVC_NAME@:${pvcName}:g" ${customPVYaml}
    sed -i -e "s:@STORAGE_ACCOUNT@:${STORAGE_ACCOUNT_NAME}:g" ${customPVYaml}
    sed -i -e "s:@FILE_SHARE_NAME@:${FILE_SHARE_NAME}:g" ${customPVYaml}

    # generate pv configurations
    customPVCYaml=${scriptDir}/pvc.yaml
    cp ${scriptDir}/pvc.yaml.template ${customPVCYaml}
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVCYaml}
    sed -i -e "s:@PVC_NAME@:${pvcName}:g" ${customPVCYaml}
    sed -i -e "s:@STORAGE_ACCOUNT@:${STORAGE_ACCOUNT_NAME}:g" ${customPVCYaml}

    kubectl apply -f ${customPVYaml}
    utility_check_pv_state ${pvName} "Available" ${checkPVStateMaxAttempt} ${checkPVStateInterval}
    kubectl apply -f ${customPVCYaml}
    utility_check_pv_state ${pvName} "Bound" ${checkPVStateMaxAttempt} ${checkPVStateInterval}

    # validate PV PVC
    ret=$(kubectl get pv | grep "${pvName}" | grep "${pvcName}")
    if [ -z "$ret" ]; then
        echo_stderr "Failed to create pv/pvc."
    fi
}

function wait_for_pod_completed() {
    echo "Waiting for $((WLS_APP_REPLICAS + 1)) pods are running."

    utility_wait_for_pod_completed \
        ${WLS_APP_REPLICAS} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    acrImagePath=${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}
    echo "Waiting for $((WLS_APP_REPLICAS + 1)) new pods created with image ${acrImagePath}"

    utility_wait_for_image_update_completed \
        "${acrImagePath}" \
        ${WLS_APP_REPLICAS} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function create_domain_namespace() {
    echo "check if namespace ${wlsDomainNS} exists?"
    ret=$(kubectl get namespace | grep "${wlsDomainNS}")

    updateNamepace=${constFalse}
    if [ -z "${ret}" ]; then
        echo "create namespace ${wlsDomainNS}"
        kubectl create namespace ${wlsDomainNS}
        kubectl label namespace ${wlsDomainNS} weblogic-operator=enabled
    else
        updateNamepace=${constTrue}
        echo "Remove existing secrets and replace with new values"
        kubectl -n ${wlsDomainNS} delete secret ${kubectlWLSCredentialName}
        kubectl -n ${wlsDomainNS} delete secret ${kubectlWDTEncryptionSecret}
        kubectl -n ${wlsDomainNS} delete secret ${kubectlSecretForACR}
    fi

    kubectl -n ${wlsDomainNS} create secret generic \
        ${kubectlWLSCredentialName} \
        --from-literal=username=${WLS_ADMIN_USER_NAME} \
        --from-literal=password=${WLS_ADMIN_PASSWORD}

    kubectl -n ${wlsDomainNS} label secret ${kubectlWLSCredentialName} weblogic.domainUID=${WLS_DOMAIN_UID}

    kubectl -n ${wlsDomainNS} create secret generic ${kubectlWDTEncryptionSecret} \
        --from-literal=password=${WLS_WDT_RUNTIME_PSW}
    kubectl -n ${wlsDomainNS} label secret ${kubectlWDTEncryptionSecret} weblogic.domainUID=${WLS_DOMAIN_UID}

    kubectl create secret docker-registry ${kubectlSecretForACR} \
        --docker-server=${ACR_LOGIN_SERVER} \
        --docker-username=${ACR_USER_NAME} \
        --docker-password=${ACR_PASSWORD} \
        -n ${wlsDomainNS}

    kubectl -n ${wlsDomainNS} label secret ${kubectlSecretForACR} weblogic.domainUID=${WLS_DOMAIN_UID}
}

function parsing_ssl_certs_and_create_ssl_secret() {
    if [[ "${ENABLE_CUSTOM_SSL,,}" == "${constTrue}" ]]; then
        # use default Java, if no, install open jdk 11.
        # why not use Microsoft open jdk? No apk installation package!
        export JAVA_HOME=/usr/lib/jvm/default-jvm/
        if [ ! -d "${JAVA_HOME}" ]; then
            install_jdk
            JAVA_HOME=/usr/lib/jvm/java-11-openjdk
        fi

        create_source_folder_for_certificates
        output_ssl_keystore
        validate_ssl_keystores
        upload_certificates_to_fileshare

        echo "check if ${kubectlWLSSSLCredentialsName} exists."
        ret=$(kubectl get secret -n ${wlsDomainNS} | grep "${kubectlWLSSSLCredentialsName}")
        if [ -n "${ret}" ]; then
            echo "delete secret  ${kubectlWLSSSLCredentialsName}"
            kubectl -n ${wlsDomainNS} delete secret ${kubectlWLSSSLCredentialsName}
        fi
        echo "create secret  ${kubectlWLSSSLCredentialsName}"
        kubectl -n ${wlsDomainNS} create secret generic ${kubectlWLSSSLCredentialsName} \
            --from-literal=sslidentitykeyalias=${WLS_SSL_PRIVATE_KEY_ALIAS} \
            --from-literal=sslidentitykeypassword=${WLS_SSL_PRIVATE_KEY_PASSWORD} \
            --from-literal=sslidentitystorepath=${sharedPath}/$wlsIdentityKeyStoreFileName \
            --from-literal=sslidentitystorepassword=${WLS_SSL_IDENTITY_PASSWORD} \
            --from-literal=sslidentitystoretype=${WLS_SSL_IDENTITY_TYPE} \
            --from-literal=ssltruststorepath=${sharedPath}/${wlsTrustKeyStoreFileName} \
            --from-literal=ssltruststoretype=${WLS_SSL_TRUST_TYPE} \
            --from-literal=ssltruststorepassword=${WLS_SSL_TRUST_PASSWORD}

        kubectl -n ${wlsDomainNS} label secret ${kubectlWLSSSLCredentialsName} weblogic.domainUID=${WLS_DOMAIN_UID}
        javaOptions=" -Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.security.SSL.trustedCAKeyStore=${sharedPath}/${wlsTrustKeyStoreJKSFileName} ${javaOptions}"
    fi
}

# Deploy WebLogic domain and cluster
#  * Create namespace for domain
#  * Create secret for weblogic
#  * Create secret for Azure file
#  * Create secret for ACR
#  * Deploy WebLogic domain using image in ACR
#  * Wait for the domain completed
function setup_wls_domain() {
    export javaOptions=${WLS_JAVA_OPTIONS}
    if [[ "${enableClusterT3Channel,,}" == "true" ]] || [[ "${enableAdminT3Channel,,}" == "true" ]]; then
        # for remote t3/t3s access.
        # refer to https://oracle.github.io/weblogic-kubernetes-operator/faq/external-clients/#enabling-unknown-host-access
        javaOptions="-Dweblogic.rjvm.allowUnknownHost=true ${javaOptions}"
    fi
    
    # create namespace
    create_domain_namespace

    echo "constTrue": "${constTrue}"
    if [[ "${ENABLE_PV,,}" == "${constTrue}" ]]; then
        echo "start to create pv/pvc. "
        create_pv
    fi

    parsing_ssl_certs_and_create_ssl_secret

    # show resources
    echo "print weblogic operator status"
    kubectl -n ${wlsOptNameSpace} get pod -o wide
    echo "print secrets that is ready to use"
    kubectl -n ${wlsDomainNS} get secret -o wide
    echo "print current configmap"
    kubectl -n ${wlsDomainNS} get configmap -o wide
    echo "print pvc info"
    kubectl -n ${wlsDomainNS} get pvc -o wide

    customDomainYaml=${scriptDir}/custom-domain.yaml
    if [[ "${updateNamepace}" == "${constTrue}" ]]; then
        echo "start to update domain  ${WLS_DOMAIN_UID}"
        chmod ugo+x $scriptDir/updateDomainConfig.sh
        bash $scriptDir/updateDomainConfig.sh \
            ${customDomainYaml} \
            "${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}" \
            "${javaOptions}"
    else
        echo "start to create domain  ${WLS_DOMAIN_UID}"
        # generate domain yaml
        chmod ugo+x $scriptDir/genDomainConfig.sh
        bash $scriptDir/genDomainConfig.sh \
            ${customDomainYaml} \
            "${ACR_LOGIN_SERVER}/aks-wls-images:${newImageTag}" \
            "${javaOptions}"
    fi

    kubectl apply -f ${customDomainYaml}

    wait_for_image_update_completed

    wait_for_pod_completed
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

export adminServerName="admin-server"
export azFileShareName=${FILE_SHARE_NAME}
export exitCode=0
export kubectlSecretForACR="regsecret"
export kubectlWDTEncryptionSecret="${WLS_DOMAIN_UID}-runtime-encryption-secret"
export kubectlWLSCredentialName="${WLS_DOMAIN_UID}-weblogic-credentials"
export kubectlWLSSSLCredentialsName="${WLS_DOMAIN_UID}-weblogic-ssl-credentials"
export newImageTag=$(date +%s)
export operatorName="weblogic-operator"
# seconds
export sasTokenValidTime=3600
export storageResourceGroup=${CURRENT_RESOURCEGROUP_NAME}
export sharedPath="/shared"
export wlsDomainNS="${WLS_DOMAIN_UID}-ns"
export wlsOptHelmChart="https://oracle.github.io/weblogic-kubernetes-operator/charts"
export wlsOptNameSpace="weblogic-operator-ns"
export wlsOptRelease="weblogic-operator"
export wlsOptSA="weblogic-operator-sa"
export wlsIdentityKeyStoreFileName="security/identity.keystore"
export wlsTrustKeyStoreFileName="security/trust.keystore"
export wlsTrustKeyStoreJKSFileName="security/trust.jks"

validate_input

get_wls_operator_version

install_utilities

query_acr_credentials

build_docker_image

connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RESOURCEGROUP_NAME

install_wls_operator

setup_wls_domain

exit $exitCode
