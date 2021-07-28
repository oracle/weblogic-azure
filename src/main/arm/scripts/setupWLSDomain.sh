# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

#Function to output message to stdout
function echo_stderr() {
    echo "$@" >&2
    echo "$@" >>stdout
}

function echo_stdout() {
    echo "$@" >&2
    echo "$@" >>stdout
}

#Function to display usage message
function usage() {
    echo_stdout "./setupWLSDomain.sh <ocrSSOUser> <ocrSSOPSW> <aksClusterRGName> <aksClusterName> <wlsImageTag> <acrName> <wlsDomainName> <wlsDomainUID> <wlsUserName> <wlsPassword> <wdtRuntimePassword> <wlsCPU> <wlsMemory> <managedServerPrefix> <appReplicas> <appPackageUrls> <currentResourceGroup> <scriptURL> <storageAccountName> <wlsClusterSize> <enableCustomSSL> <wlsIdentityData> <wlsIdentityPsw> <wlsIdentityType> <wlsIdentityAlias> <wlsIdentityKeyPsw> <wlsTrustData> <wlsTrustPsw> <wlsTrustType> <gatewayAlias> <enablePV>"
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

    if [ -z "$gatewayAlias" ]; then
        echo_stderr "gatewayAlias is required. "
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

# Install WebLogic operator using charts from GitHub Repo
# * Create namespace weblogic-operator-ns
# * Create service account
# * install operator
function install_wls_operator() {
    kubectl create namespace ${wlsOptNameSpace}
    kubectl -n ${wlsOptNameSpace} create serviceaccount ${wlsOptSA}

    helm repo add ${wlsOptRelease} ${wlsOptHelmChart} --force-update
    ret=$(helm repo list)
    validate_status ${ret}
    helm install ${wlsOptRelease} weblogic-operator/weblogic-operator \
        --namespace ${wlsOptNameSpace} \
        --set serviceAccount=${wlsOptSA} \
        --set "enableClusterRoleBinding=true" \
        --set "domainNamespaceSelectionStrategy=LabelSelector" \
        --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
        --wait

    validate_status "Installing WLS operator."

    # valiadate weblogic operator
    ret=$(kubectl get pod -n ${wlsOptNameSpace} | grep "Running")
    if [ -z "$ret" ]; then
        echo_stderr "Failed to install WebLogic operator."
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
    resourceGroupName="${currentResourceGroup}"
    fileShareName="${azFileShareName}"

    # Disable https-only
    az storage account update --name ${storageAccountName} --resource-group ${resourceGroupName} --https-only false

    mntRoot="/wls"
    mntPath="$mntRoot/$storageAccountName/$fileShareName"

    mkdir -p $mntPath

    httpEndpoint=$(az storage account show \
        --resource-group $resourceGroupName \
        --name $storageAccountName \
        --query "primaryEndpoints.file" | tr -d '"')
    smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))$fileShareName

    mount -t cifs $smbPath $mntPath -o username=$storageAccountName,password=$storageAccountKey,serverino,vers=3.0,file_mode=0777,dir_mode=0777
    validate_status "Mounting path."
}

function unmount_fileshare() {
    echo "unmount fileshare."
    umount ${mntPath}
    # Disable https-only
    az storage account update --name ${storageAccountName} --resource-group ${currentResourceGroup} --https-only true
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
    export storageAccountKey=$(az storage account keys list --resource-group $currentResourceGroup --account-name $storageAccountName --query "[0].value" -o tsv)
    export azureSecretName="azure-secret"
    kubectl -n ${wlsDomainNS} create secret generic ${azureSecretName} \
        --from-literal=azurestorageaccountname=${storageAccountName} \
        --from-literal=azurestorageaccountkey=${storageAccountKey}

    # generate pv configurations
    customPVYaml=${scriptDir}/pv.yaml
    cp ${scriptDir}/pv.yaml.template ${customPVYaml}
    pvName=${wlsDomainUID}-pv-azurefile
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVYaml}
    sed -i -e "s:@PV_NME@:${pvName}:g" ${customPVYaml}

    # generate pv configurations
    customPVCYaml=${scriptDir}/pvc.yaml
    cp ${scriptDir}/pvc.yaml.template ${customPVCYaml}
    pvcName=${wlsDomainUID}-pvc-azurefile
    sed -i -e "s:@NAMESPACE@:${wlsDomainNS}:g" ${customPVCYaml}
    sed -i -e "s:@PVC_NAME@:${pvcName}:g" ${customPVCYaml}

    kubectl apply -f ${customPVYaml}
    kubectl apply -f ${customPVCYaml}

    # validate PV PVC
    ret=$(kubectl get pv | grep "${pvName}" | grep "${pvcName}")
    if [ -z "$ret" ]; then
        echo_stderr "Failed to create pv/pvc."
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
    kubectl create namespace ${wlsDomainNS}
    kubectl label namespace ${wlsDomainNS} weblogic-operator=enabled

    kubectl -n ${wlsDomainNS} create secret generic \
        ${kubectlWLSCredentials} \
        --from-literal=username=${wlsUserName} \
        --from-literal=password=${wlsPassword}

    kubectl -n ${wlsDomainNS} label secret ${kubectlWLSCredentials} weblogic.domainUID=${wlsDomainUID}

    kubectl -n ${wlsDomainNS} create secret generic ${wlsDomainUID}-runtime-encryption-secret \
        --from-literal=password=${wdtRuntimePassword}
    kubectl -n ${wlsDomainNS} label secret ${wlsDomainUID}-runtime-encryption-secret weblogic.domainUID=${wlsDomainUID}

    kubectl create secret docker-registry ${kubectlSecretForACR} \
        --docker-server=${azureACRServer} \
        --docker-username=${azureACRUserName} \
        --docker-password=${azureACRPassword} \
        -n ${wlsDomainNS}

    if [[ "${enablePV,,}" == "true" ]]; then
        create_pv
    fi

    export javaOptions=""
    if [[ "${enableCustomSSL,,}" == "true" ]]; then
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

    # generate domain yaml
    customDomainYaml=${scriptDir}/custom-domain.yaml
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

    kubectl apply -f ${customDomainYaml}

    wait_for_domain_completed
}

function wait_for_domain_completed() {
    attempts=0
    svcState="running"
    while [ ! "$svcState" == "completed" ] && [ $attempts -lt 10 ]; do
        svcState="completed"
        attempts=$((attempts + 1))
        echo Waiting for job completed...${attempts}
        sleep 2m

        # If the job is completed, there should have the following services created,
        #    ${domainUID}-${adminServerName}, e.g. domain1-admin-server
        adminServiceCount=$(kubectl -n ${wlsDomainNS} get svc | grep -c "${wlsDomainUID}-${adminServerName}")
        if [ ${adminServiceCount} -lt 1 ]; then svcState="running"; fi

        # If the job is completed, there should have the following services created, .assuming initialManagedServerReplicas=2
        #    ${domainUID}-${managedServerNameBase}1, e.g. domain1-managed-server1
        #    ${domainUID}-${managedServerNameBase}2, e.g. domain1-managed-server2
        managedServiceCount=$(kubectl -n ${wlsDomainNS} get svc | grep -c "${wlsDomainUID}-${managedServerPrefix}")
        if [ ${managedServiceCount} -lt ${appReplicas} ]; then svcState="running"; fi

        # If the job is completed, there should have no service in pending status.
        pendingCount=$(kubectl -n ${wlsDomainNS} get pod | grep -c "pending")
        if [ ${pendingCount} -ne 0 ]; then svcState="running"; fi

        # If the job is completed, there should have the following pods running
        #    ${domainUID}-${adminServerName}, e.g. domain1-admin-server
        #    ${domainUID}-${managedServerNameBase}1, e.g. domain1-managed-server1
        #    to
        #    ${domainUID}-${managedServerNameBase}n, e.g. domain1-managed-servern, n = initialManagedServerReplicas
        runningPodCount=$(kubectl -n ${wlsDomainNS} get pods | grep "${wlsDomainUID}" | grep -c "Running")
        if [[ $runningPodCount -le ${appReplicas} ]]; then svcState="running"; fi
    done

    # If all the services are completed, print service details
    # Otherwise, ask the user to refer to document for troubleshooting
    if [ "$svcState" == "completed" ]; then
        kubectl -n ${wlsDomainNS} get pods
        kubectl -n ${wlsDomainNS} get svc
    else
        echo WARNING: WebLogic domain is not ready. It takes too long to create domain, please refer to http://oracle.github.io/weblogic-kubernetes-operator/samples/simple/azure-kubernetes-service/#troubleshooting
        exitCode=1
    fi
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
export gatewayAlias=${30}
export enablePV=${31}

export adminServerName="admin-server"
export azFileShareName="weblogic"
export exitCode=0
export ocrLoginServer="container-registry.oracle.com"
export kubectlSecretForACR="regsecret"
export kubectlWLSCredentials="${wlsDomainUID}-weblogic-credentials"
export kubectlWLSSSLCredentials="${wlsDomainUID}-weblogic-ssl-credentials"
export newImageTag=$(date +%s)
export storageFileShareName="weblogic"
export sharedPath="/shared"
export wlsDomainNS="${wlsDomainUID}-ns"
export wlsOptHelmChart="https://oracle.github.io/weblogic-kubernetes-operator/charts"
export wlsOptNameSpace="weblogic-operator-ns"
export wlsOptRelease="weblogic-operator"
export wlsOptSA="weblogic-operator-sa"
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
