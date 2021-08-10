# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

#Function to output message to stdout
function echo_stderr() {
    echo "$@" >&2
    echo "$@" >>stdout
}

function echo_stdout() {
    echo "$@"
    echo "$@" >>stdout
}

#Function to display usage message
function usage() {
    cat<<EOF
Usage: 
./setupWLSDomain.sh \
    <ocrSSOUser> \
    <ocrSSOPSW> \
    <aksClusterRGName> \
    <aksClusterName> \
    <wlsImageTag> \
    <acrName> \
    <wlsDomainName> \
    <wlsDomainUID> \
    <wlsUserName> \
    <wlsPassword> \
    <wdtRuntimePassword> \
    <wlsCPU> \
    <wlsMemory> \
    <managedServerPrefix> \
    <appReplicas> \
    <appPackageUrls> \
    <currentResourceGroup> \
    <scriptURL> \
    <storageAccountName> \
    <wlsClusterSize> \
    <enableCustomSSL> \
    <wlsIdentityData> \
    <wlsIdentityPsw> \
    <wlsIdentityType> \
    <wlsIdentityAlias> \
    <wlsIdentityKeyPsw> \
    <wlsTrustData> \
    <wlsTrustPsw> \
    <wlsTrustType> \
    <enablePV>
EOF
    if [ $1 -eq 1 ]; then
        exit 1
    fi
}

#Function to validate input
function validate_input() {
    if [[ -z "$ocrSSOUser" || -z "${ocrSSOPSW}" ]]; then
        echo_stderr "Oracle SSO account is required. "
        usage 1
    fi

    if [[ -z "$aksClusterRGName" || -z "${aksClusterName}" ]]; then
        echo_stderr "AKS cluster name and resource group name are required. "
        usage 1
    fi

    if [ -z "$wlsImageTag" ]; then
        echo_stderr "wlsImageTag is required. "
        usage 1
    fi

    if [ -z "$acrName" ]; then
        echo_stderr "acrName is required. "
        usage 1
    fi

    if [ -z "$wlsDomainName" ]; then
        echo_stderr "wlsDomainName is required. "
        usage 1
    fi

    if [ -z "$wlsDomainUID" ]; then
        echo_stderr "wlsDomainUID is required. "
        usage 1
    fi

    if [ -z "$wlsUserName" ]; then
        echo_stderr "wlsUserName is required. "
        usage 1
    fi

    if [ -z "$wlsPassword" ]; then
        echo_stderr "wlsPassword is required. "
        usage 1
    fi

    if [ -z "$wdtRuntimePassword" ]; then
        echo_stderr "wdtRuntimePassword is required. "
        usage 1
    fi

    if [ -z "$wlsCPU" ]; then
        echo_stderr "wlsCPU is required. "
        usage 1
    fi

    if [ -z "$wlsMemory" ]; then
        echo_stderr "wlsMemory is required. "
        usage 1
    fi

    if [ -z "$managedServerPrefix" ]; then
        echo_stderr "managedServerPrefix is required. "
        usage 1
    fi

    if [ -z "$appReplicas" ]; then
        echo_stderr "appReplicas is required. "
        usage 1
    fi

    if [ -z "$appPackageUrls" ]; then
        echo_stderr "appPackageUrls is required. "
        usage 1
    fi

    if [ -z "$currentResourceGroup" ]; then
        echo_stderr "currentResourceGroup is required. "
        usage 1
    fi

    if [ -z "$scriptURL" ]; then
        echo_stderr "scriptURL is required. "
        usage 1
    fi

    if [ -z "$storageAccountName" ]; then
        echo_stderr "storageAccountName is required. "
        usage 1
    fi

    if [ -z "$wlsClusterSize" ]; then
        echo_stderr "wlsClusterSize is required. "
        usage 1
    fi

    if [ -z "$enableCustomSSL" ]; then
        echo_stderr "enableCustomSSL is required. "
        usage 1
    fi

    if [[ -z "$wlsIdentityData" || -z "${wlsIdentityPsw}" ]]; then
        echo_stderr "wlsIdentityPsw and wlsIdentityData are required. "
        usage 1
    fi

    if [ -z "$wlsIdentityType" ]; then
        echo_stderr "wlsIdentityType is required. "
        usage 1
    fi

    if [[ -z "$wlsIdentityAlias" || -z "${wlsIdentityKeyPsw}" ]]; then
        echo_stderr "wlsIdentityAlias and wlsIdentityKeyPsw are required. "
        usage 1
    fi

    if [[ -z "$wlsTrustData" || -z "${wlsTrustPsw}" ]]; then
        echo_stderr "wlsIdentityAlias and wlsIdentityKeyPsw are required. "
        usage 1
    fi

    if [ -z "$wlsTrustType" ]; then
        echo_stderr "wlsTrustType is required. "
        usage 1
    fi

    if [ -z "$enablePV" ]; then
        echo_stderr "enablePV is required. "
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

# Install latest kubectl and helm
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

    # Install helm
    browserURL=$(curl -m ${curlMaxTime} -s https://api.github.com/repos/helm/helm/releases/latest |
        grep "browser_download_url.*linux-amd64.tar.gz.asc" |
        cut -d : -f 2,3 |
        tr -d \")
    helmLatestVersion=${browserURL#*download\/}
    helmLatestVersion=${helmLatestVersion%%\/helm*}
    helmPackageName=helm-${helmLatestVersion}-linux-amd64.tar.gz
    curl -m ${curlMaxTime} -fL https://get.helm.sh/${helmPackageName} -o /tmp/${helmPackageName}
    tar -zxvf /tmp/${helmPackageName} -C /tmp
    mv /tmp/linux-amd64/helm /usr/local/bin/helm
    echo "helm version"
    helm version
    validate_status "Finished installing helm."

    echo "az cli version"
    ret=$(az --version)
    validate_status ${ret}
}

# Connect to AKS cluster
function connect_aks_cluster() {
    az aks get-credentials --resource-group ${aksClusterRGName} --name ${aksClusterName} --overwrite-existing
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
    helm install ${wlsOptRelease} weblogic-operator/weblogic-operator \
    --namespace ${wlsOptNameSpace} \
    --set serviceAccount=${wlsOptSA} \
    --set "enableClusterRoleBinding=true" \
    --set "domainNamespaceSelectionStrategy=LabelSelector" \
    --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
    --version ${wlsOptVersion} \
    --wait

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
    azureACRServer=$(az acr show -n $acrName --query 'loginServer' -o tsv)
    validate_status ${azureACRServer}
    azureACRUserName=$(az acr credential show -n $acrName --query 'username' -o tsv)
    azureACRPassword=$(az acr credential show -n $acrName --query 'passwords[0].value' -o tsv)
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
    bash $scriptDir/createVMAndBuildImage.sh \
        $currentResourceGroup \
        $wlsImageTag \
        $azureACRServer \
        $azureACRUserName \
        $azureACRPassword \
        $newImageTag \
        "$appPackageUrls" \
        $ocrSSOUser \
        $ocrSSOPSW \
        $wlsClusterSize \
        $enableCustomSSL \
        "$scriptURL"
    
    az acr repository show -n ${acrName} --image aks-wls-images:${newImageTag}
    if [ $? -ne 0 ]; then
        echo "Failed to create image ${azureACRServer}/aks-wls-images:${newImageTag}"
        exit 1
    fi
}

function mount_fileshare() {
    fileShareName="${azFileShareName}"

    # Disable https-only
    az storage account update --name ${storageAccountName} --resource-group ${storageResourceGroup} --https-only false

    mntRoot="/wls"
    mntPath="$mntRoot/$storageAccountName/$fileShareName"

    mkdir -p $mntPath

    httpEndpoint=$(
        az storage account show \
        --resource-group $storageResourceGroup \
        --name $storageAccountName \
        --query "primaryEndpoints.file" | tr -d '"'
    )
    smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))$fileShareName

    export storageAccountKey=$(az storage account keys list \
        --resource-group $storageResourceGroup \
        --account-name $storageAccountName \
        --query "[0].value" -o tsv)

    mount -t cifs $smbPath $mntPath -o username=$storageAccountName,password=$storageAccountKey,serverino,vers=3.0,file_mode=0777,dir_mode=0777
    validate_status "Mounting path."
}

function unmount_fileshare() {
    echo "unmount fileshare."
    umount ${mntPath}
    # Disable https-only
    az storage account update --name ${storageAccountName} --resource-group ${storageResourceGroup} --https-only true
}

function validate_ssl_keystores() {
    #validate if identity keystore has entry
    ${JAVA_HOME}/bin/keytool -list -v \
        -keystore ${mntPath}/$wlsIdentityKeyStoreFileName \
        -storepass $wlsIdentityPsw \
        -storetype $wlsIdentityType |
        grep 'Entry type:' |
        grep 'PrivateKeyEntry'

    validate_status "Validate Identity Keystore."

    #validate if trust keystore has entry
    ${JAVA_HOME}/bin/keytool -list -v \
        -keystore ${mntPath}/${wlsTrustKeyStoreFileName} \
        -storepass $wlsTrustPsw \
        -storetype $wlsTrustType |
        grep 'Entry type:' |
        grep 'trustedCertEntry'

    validate_status "Validate Trust Keystore."

    #validate if trust keystore has entry
    ${JAVA_HOME}/bin/keytool -list -v \
        -keystore ${mntPath}/${wlsTrustKeyStoreFileName} \
        -storepass $wlsTrustPsw \
        -storetype jks |
        grep 'Entry type:' |
        grep 'trustedCertEntry'

    ${JAVA_HOME}/bin/keytool -list -v \
        -keystore ${mntPath}/${wlsTrustKeyStoreJKSFileName} \
        -storepass $wlsTrustPsw \
        -storetype jks |
        grep 'Entry type:' |
        grep 'trustedCertEntry'

    validate_status "Validate Trust Keystore."

    echo "Validate SSL key stores successfull !!"
}

function output_ssl_keystore() {
    echo "Custom SSL is enabled. Storing CertInfo as files..."
    # Create a folder for certificates
    securityDir=${mntPath}/security
    if [ ! -d "${securityDir}" ]; then
        mkdir ${mntPath}/security
    else
        rm -f ${mntPath}/$wlsIdentityKeyStoreFileName
        rm -f ${mntPath}/$wlsTrustKeyStoreFileName
        rm -f ${mntPath}/${wlsIdentityRootCertFileName}
        rm -f ${mntPath}/${wlsTrustKeyStoreJKSFileName}
    fi

    #decode cert data once again as it would got base64 encoded
    echo "$wlsIdentityData" | base64 -d >${mntPath}/$wlsIdentityKeyStoreFileName
    echo "$wlsTrustData" | base64 -d >${mntPath}/$wlsTrustKeyStoreFileName
    # export root cert. Used as gateway backend certificate
    ${JAVA_HOME}/bin/keytool -export \
        -alias ${wlsIdentityAlias} \
        -noprompt \
        -file ${mntPath}/${wlsIdentityRootCertFileName} \
        -keystore ${mntPath}/$wlsIdentityKeyStoreFileName \
        -storepass ${wlsIdentityPsw}

    # export jks file
    # -Dweblogic.security.SSL.trustedCAKeyStorePassPhrase for PKCS12 is not working correctly
    # we neet to convert PKCS12 file to JKS file and specify in domain.yaml via -Dweblogic.security.SSL.trustedCAKeyStore
    if [[ "${wlsTrustType,,}" != "jks" ]]; then
        ${JAVA_HOME}/bin/keytool -importkeystore \
            -srckeystore ${mntPath}/${wlsTrustKeyStoreFileName} \
            -srcstoretype ${wlsTrustType} \
            -srcstorepass ${wlsTrustPsw} \
            -destkeystore ${mntPath}/${wlsTrustKeyStoreJKSFileName} \
            -deststoretype jks \
            -deststorepass ${wlsTrustPsw}

        validate_status "Export trust JKS file."
    else
        echo "$wlsTrustData" | base64 -d >${mntPath}/${wlsTrustKeyStoreJKSFileName}
    fi
}

# Create storage for AKS cluster
# * Create secret for storage account
# * Create PV using Azure file share
# * Create PVC
function create_pv() {
    echo "check if pv/pvc have been created."
    pvcName=${wlsDomainUID}-pvc-azurefile
    pvName=${wlsDomainUID}-pv-azurefile
    ret=$(kubectl -n ${wlsDomainNS} get pvc ${pvcName} | grep "Bound")

    if [ -n "$ret" ]; then
        echo "pvc is bound to namespace ${wlsDomainNS}."
        # this is a workaround for update domain using marketplace offer.
        # the offer will create a new storage account in a new resource group.
        # remove the new storage account.
        currentStorageAccount=$(kubectl get pv ${pvName} -o json | jq '. | .metadata.labels.storageAccount' | tr -d "\"")
        if [[ "${currentStorageAccount}" != "${storageAccountName}" ]]; then
            echo "the cluster is bound to pv on storage account ${currentStorageAccount}"
            az storage account delete -n ${storageAccountName} -g $currentResourceGroup -y
            storageAccountName=${currentStorageAccount} # update storage account name
            echo "query storage account resource group"
            storageResourceGroup=$(az storage account show --name ${storageAccountName} | jq '.resourceGroup' | tr -d "\"")
            echo "resource group that contains storage account ${storageAccountName} is ${storageResourceGroup}"
        fi

        return
    fi

    echo "create pv/pvc."
    export storageAccountKey=$(az storage account keys list --resource-group $storageResourceGroup --account-name $storageAccountName --query "[0].value" -o tsv)
    export azureSecretName="azure-secret"
    kubectl -n ${wlsDomainNS} create secret generic ${azureSecretName} \
    --from-literal=azurestorageaccountname=${storageAccountName} \
    --from-literal=azurestorageaccountkey=${storageAccountKey}

    # generate pv configurations
    customPVYaml=${scriptDir}/pv.yaml
    cp ${scriptDir}/pv.yaml.template ${customPVYaml}
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVYaml}
    sed -i -e "s:@PV_NAME@:${pvName}:g" ${customPVYaml}
    sed -i -e "s:@PVC_NAME@:${pvcName}:g" ${customPVYaml}
    sed -i -e "s:@STORAGE_ACCOUNT@:${storageAccountName}:g" ${customPVYaml}

    # generate pv configurations
    customPVCYaml=${scriptDir}/pvc.yaml
    cp ${scriptDir}/pvc.yaml.template ${customPVCYaml}
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVCYaml}
    sed -i -e "s:@PVC_NAME@:${pvcName}:g" ${customPVCYaml}
    sed -i -e "s:@STORAGE_ACCOUNT@:${storageAccountName}:g" ${customPVCYaml}

    kubectl apply -f ${customPVYaml}
    kubectl apply -f ${customPVCYaml}

    # validate PV PVC
    ret=$(kubectl get pv | grep "${pvName}" | grep "${pvcName}")
    if [ -z "$ret" ]; then
        echo_stderr "Failed to create pv/pvc."
    fi
}

function wait_for_pod_completed() {
    echo "Waiting for $((appReplicas+1)) pods are running."

    utility_wait_for_pod_completed \
        ${appReplicas} \
        "${wlsDomainNS}" \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    acrImagePath=${azureACRServer}/aks-wls-images:${newImageTag}
    echo "Waiting for $((appReplicas+1)) new pods created with image ${acrImagePath}"
    
    utility_wait_for_image_update_completed \
        "${acrImagePath}" \
        ${appReplicas} \
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
        kubectl -n ${wlsDomainNS} delete secret ${kubectlWLSCredentials}
        kubectl -n ${wlsDomainNS} delete secret ${kubectlWDTEncryptionSecret}
        kubectl -n ${wlsDomainNS} delete secret ${kubectlSecretForACR}
    fi

    kubectl -n ${wlsDomainNS} create secret generic \
    ${kubectlWLSCredentials} \
    --from-literal=username=${wlsUserName} \
    --from-literal=password=${wlsPassword}

    kubectl -n ${wlsDomainNS} label secret ${kubectlWLSCredentials} weblogic.domainUID=${wlsDomainUID}

    kubectl -n ${wlsDomainNS} create secret generic ${kubectlWDTEncryptionSecret} \
    --from-literal=password=${wdtRuntimePassword}
    kubectl -n ${wlsDomainNS} label secret ${kubectlWDTEncryptionSecret} weblogic.domainUID=${wlsDomainUID}

    kubectl create secret docker-registry ${kubectlSecretForACR} \
    --docker-server=${azureACRServer} \
    --docker-username=${azureACRUserName} \
    --docker-password=${azureACRPassword} \
    -n ${wlsDomainNS}

    kubectl -n ${wlsDomainNS} label secret ${kubectlSecretForACR} weblogic.domainUID=${wlsDomainUID}
}

function parsing_ssl_certs_and_create_ssl_secret() {
    export javaOptions=""
    if [[ "${enableCustomSSL,,}" == "${constTrue}" ]]; then
        # use default Java, if no, install open jdk 11.
        # why not Microsoft open jdk? No apk installation package!
        export JAVA_HOME=/usr/lib/jvm/default-jvm/
        if [ ! -d "${JAVA_HOME}" ]; then
            install_jdk
            JAVA_HOME=/usr/lib/jvm/java-11-openjdk
        fi

        mount_fileshare
        output_ssl_keystore
        validate_ssl_keystores
        unmount_fileshare

        echo "check if ${kubectlWLSSSLCredentials} exists."
        ret=$(kubectl get secret -n ${wlsDomainNS} | grep "${kubectlWLSSSLCredentials}")
        if [ -n "${ret}" ]; then
            echo "delete secret  ${kubectlWLSSSLCredentials}"
            kubectl -n ${wlsDomainNS} delete secret ${kubectlWLSSSLCredentials}
        fi
        echo "create secret  ${kubectlWLSSSLCredentials}"
        kubectl -n ${wlsDomainNS} create secret generic ${kubectlWLSSSLCredentials} \
            --from-literal=sslidentitykeyalias=${wlsIdentityAlias} \
            --from-literal=sslidentitykeypassword=${wlsIdentityKeyPsw} \
            --from-literal=sslidentitystorepath=${sharedPath}/$wlsIdentityKeyStoreFileName \
            --from-literal=sslidentitystorepassword=${wlsIdentityPsw} \
            --from-literal=sslidentitystoretype=${wlsIdentityType} \
            --from-literal=ssltruststorepath=${sharedPath}/${wlsTrustKeyStoreFileName} \
            --from-literal=ssltruststoretype=${wlsTrustType} \
            --from-literal=ssltruststorepassword=${wlsTrustPsw}

        kubectl -n ${wlsDomainNS} label secret ${kubectlWLSSSLCredentials} weblogic.domainUID=${wlsDomainUID}
        javaOptions="-Dweblogic.security.SSL.ignoreHostnameVerification=true -Dweblogic.security.SSL.trustedCAKeyStore=${sharedPath}/${wlsTrustKeyStoreJKSFileName}"
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
    # create namespace
    create_domain_namespace

    echo "constTrue": "${constTrue}"
    if [[ "${enablePV,,}" == "${constTrue}" ]]; then
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
        echo "start to update domain  ${wlsDomainUID}"
        chmod ugo+x $scriptDir/updateDomainConfig.sh
        bash $scriptDir/updateDomainConfig.sh \
        ${customDomainYaml} \
        ${appReplicas} \
        ${wlsCPU} \
        ${wlsDomainUID} \
        ${wlsDomainName} \
        "${azureACRServer}/aks-wls-images:${newImageTag}" \
        ${wlsMemory} \
        ${managedServerPrefix} \
        ${enableCustomSSL} \
        ${enablePV} \
        "${javaOptions}"
    else
        echo "start to create domain  ${wlsDomainUID}"
        # generate domain yaml
        chmod ugo+x $scriptDir/genDomainConfig.sh
        bash $scriptDir/genDomainConfig.sh \
        ${customDomainYaml} \
        ${appReplicas} \
        ${wlsCPU} \
        ${wlsDomainUID} \
        ${wlsDomainName} \
        "${azureACRServer}/aks-wls-images:${newImageTag}" \
        ${wlsMemory} \
        ${managedServerPrefix} \
        ${enableCustomSSL} \
        ${enablePV} \
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

export ocrSSOUser=$1
export ocrSSOPSW=$2
export aksClusterRGName=$3
export aksClusterName=$4
export wlsImageTag=$5
export acrName=$6
export wlsDomainName=$7
export wlsDomainUID=$8
export wlsUserName=$9
export wlsPassword=${10}
export wdtRuntimePassword=${11}
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
export wlsIdentityPsw=${23}
export wlsIdentityType=${24}
export wlsIdentityAlias=${25}
export wlsIdentityKeyPsw=${26}
export wlsTrustData=${27}
export wlsTrustPsw=${28}
export wlsTrustType=${29}
export enablePV=${30}

export adminServerName="admin-server"
export azFileShareName="weblogic"
export exitCode=0
export kubectlSecretForACR="regsecret"
export kubectlWLSCredentials="${wlsDomainUID}-weblogic-credentials"
export kubectlWLSSSLCredentials="${wlsDomainUID}-weblogic-ssl-credentials"
export kubectlWDTEncryptionSecret="${wlsDomainUID}-runtime-encryption-secret"
export newImageTag=$(date +%s)
export operatorName="weblogic-operator"
export storageFileShareName="weblogic"
export storageResourceGroup=${currentResourceGroup}
export sharedPath="/shared"
export wlsDomainNS="${wlsDomainUID}-ns"
export wlsOptHelmChart="https://oracle.github.io/weblogic-kubernetes-operator/charts"
export wlsOptNameSpace="weblogic-operator-ns"
export wlsOptRelease="weblogic-operator"
export wlsOptSA="weblogic-operator-sa"
export wlsOptVersion="3.2.5"
export wlsIdentityKeyStoreFileName="security/identity.keystore"
export wlsTrustKeyStoreFileName="security/trust.keystore"
export wlsTrustKeyStoreJKSFileName="security/trust.jks"
export wlsIdentityRootCertFileName="security/root.cert"

validate_input

install_utilities

query_acr_credentials

build_docker_image

connect_aks_cluster

install_wls_operator

setup_wls_domain

exit $exitCode
