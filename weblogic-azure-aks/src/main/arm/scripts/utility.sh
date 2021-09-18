# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

function echo_stderr() {
    echo >&2 "$@"
    # The function is used for scripts running within Azure Deployment Script
    # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
    echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/errors.log
}

function echo_stdout() {
    echo "$@"
    # The function is used for scripts running within Azure Deployment Script
    # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
    echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/debug.log
}

#Validate teminal status with $?, exit with exception if errors happen.
function utility_validate_status() {
  if [ $? == 1 ]; then
    echo_stderr "$@"
    echo_stderr "Errors happen, exit 1."
    exit 1
  else
    echo_stdout "$@"
  fi
}

function install_jdk() {
    # Install Microsoft OpenJDK
    apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

    echo "java version"
    java -version
    if [ $? -eq 1 ]; then
        echo_stderr "Failed to install open jdk 11."
        exit 1
    fi
    # JAVA_HOME=/usr/lib/jvm/java-11-openjdk
}

function install_kubectl() {
    # Install kubectl
    az aks install-cli
    echo "validate kubectl"
    kubectl --help
    if [ $? -eq 1 ]; then
        echo_stderr "Failed to install kubectl."
        exit 1
    fi
}

function install_helm() {
    # Install Helm
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
    echo "Helm version"
    helm version
    utility_validate_status "Finished installing Helm."
}

# Query service port
# $1: service name
# $2: namespace
# $3: channel name
# return: port
# Notes: channel name will be different if istio is enabled.
function utility_query_service_port() {
    local port=$(kubectl get service ${1} -n ${2} -o json |
        jq ".spec.ports[] | select(.name==\"${3}\") | .port")
    if [ $? != 0 ] || [[ "$port" == "null" ]]; then
        echo_stderr "Failed to query port of ${1}/${3} in namespace ${2}"
        exit 1
    fi

    echo $port
}

#
# Check the state of a persistent volume.
# Leverage source code from function "checkPvState" in weblogic-operator, kubernetes\samples\scripts\common\utility.sh
# $1 - name of volume
# $2 - expected state of volume
# $3 - max attempt
# $4 - interval
function utility_check_pv_state {

    echo_stdout "Checking if the persistent volume ${1:?} is ${2:?}"
    local pv_state=$(kubectl get pv $1 -o jsonpath='{.status.phase}')
    attempts=0
    while [ ! "$pv_state" = "$2" ] && [ ! $attempts -eq $3 ]; do
        attempts=$((attempts + 1))
        sleep $4
        pv_state=$(kubectl get pv $1 -o jsonpath='{.status.phase}')
    done
    if [ "$pv_state" != "$2" ]; then
        echo_stderr "The persistent volume state should be $2 but is $pv_state"
        exit 1
    fi
}

#
# Create directory in specified file share
# $1 - name of directory
# $2 - name of file share
# $3 - name of storage account
# $4 - sas token
function utility_create_directory_to_fileshare() {
    ret=$(az storage directory exists --name $1 --share-name $2 --account-name $3 --sas-token ${4} | jq '.exists')
    if [[ "${ret,,}" == "false" ]]; then
        az storage directory create --name $1 --share-name $2 --account-name $3 --sas-token ${4} --timeout 30
    fi

    if [ $? != 0 ]; then
        echo_stderr "Failed to create directory ${1} in file share ${3}/${2}"
        exit 1
    fi
}

#
# Upload file to file share
# $1 - name of file share
# $2 - name of storage account
# $3 - path of file
# $4 - source path of file
# $5 - sas token
function utility_upload_file_to_fileshare() {
    az storage file upload --share-name ${1} --account-name ${2} --path ${3} --source ${4} --sas-token ${5} --timeout 60
    if [ $? != 0 ]; then
        echo_stderr "Failed to upload ${3} to file share ${2}/${1}"
        exit 1
    fi
}

# Call this function to make sure pods of a domain are running.
#   * Make sure the admin server pod is running
#   * Make sure all the managed server pods are running
# Assuming there is only one cluster in the domain
# Parameters:
#   * appReplicas: replicas of the managed server
#   * wlsDomainNS: name space
#   * checkPodStatusMaxAttemps: max attempts to query the pods status if they are not all running.
#   * checkPodStatusInterval: interval of query the pods status
function utility_wait_for_pod_completed() {
    appReplicas=$1
    wlsDomainNS=$2
    checkPodStatusMaxAttemps=$3
    checkPodStatusInterval=$4

    echo "Waiting for $((appReplicas + 1)) pods are running."

    readyPodNum=0
    attempt=0
    while [[ ${readyPodNum} -le ${appReplicas} && $attempt -le ${checkPodStatusMaxAttemps} ]]; do
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json |
            jq '.items[] | .status.phase' |
            grep "Running")
        if [ -z "${ret}" ]; then
            readyPodNum=0
        else
            readyPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json |
                jq '.items[] | .status.phase' |
                grep -c "Running")
        fi
        echo "Number of new running pod: ${readyPodNum}"
        attempt=$((attempt + 1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ]; then
        echo_stderr "It takes too long to wait for all the pods are running, please refer to http://oracle.github.io/weblogic-kubernetes-operator/samples/simple/azure-kubernetes-service/#troubleshooting"
        exit 1
    fi
}

# Call this function to make sure pods of a domain are updated with expected image.
#   * Make sure the admin server pod is updated with expected image
#   * Make sure all the managed server pods are updated with expected image
# Assuming there is only one cluster in the domain
# Parameters:
#   * acrImagePath: image path
#   * appReplicas: replicas of the managed server
#   * wlsDomainNS: name space
#   * checkPodStatusMaxAttemps: max attempts to query the pods status if they are not all running.
#   * checkPodStatusInterval: interval of query the pods status
function utility_wait_for_image_update_completed() {
    # Make sure all of the pods are updated with new image.
    # Assumption: we have only one cluster currently.
    acrImagePath=$1
    appReplicas=$2
    wlsDomainNS=$3
    checkPodStatusMaxAttemps=$4
    checkPodStatusInterval=$5

    echo "Waiting for $((appReplicas + 1)) new pods created with image ${acrImagePath}"

    updatedPodNum=0
    attempt=0
    while [ ${updatedPodNum} -le ${appReplicas} ] && [ $attempt -le ${checkPodStatusMaxAttemps} ]; do
        echo "attempts ${attempt}"
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json |
            jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' |
            grep "${acrImagePath}")

        if [ -z "${ret}" ]; then
            updatedPodNum=0
        else
            updatedPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json |
                jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' |
                grep -c "${acrImagePath}")
        fi
        echo "Number of new pod: ${updatedPodNum}"

        attempt=$((attempt + 1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ]; then
        echo_stderr "Failed to update image ${acrImagePath} to all weblogic server pods. "
        exit 1
    fi
}

# Call this function to make sure pods of a domain are restarted.
# Assuming there is only one cluster in the domain
# Parameters:
#   * baseTime: time stamp that should be earlier then pod restarts
#   * appReplicas: replicas of the managed server
#   * wlsDomainNS: name space
#   * checkPodStatusMaxAttemps: max attempts to query the pods status if they are not all running.
#   * checkPodStatusInterval: interval of query the pods status
function utility_wait_for_pod_restarted() {
    baseTime=$1
    appReplicas=$2
    wlsDomainUID=$3
    checkPodStatusMaxAttemps=$4
    checkPodStatusInterval=$5

    wlsDomainNS=${wlsDomainUID}-ns

    updatedPodNum=0
    attempt=0
    while [ ${updatedPodNum} -le ${appReplicas} ] && [ $attempt -le ${checkPodStatusMaxAttemps} ]; do
        echo "attempts ${attempt}"
        ret=$(kubectl get pods -n ${wlsDomainNS} -l weblogic.domainUID=${wlsDomainUID} -o json |
            jq '.items[] | .metadata.creationTimestamp' | tr -d "\"")

        counter=0
        for item in $ret; do
            # conver the time format from YYYY-MM-DDThh:mm:ssZ to YYYY.MM.DD-hh:mm:ss
            alpineItem=$(echo "${item}" | sed -e "s/-/./g;s/T/-/g;s/Z//g")
            podCreateTimeStamp=$(date -u -d "${alpineItem}" +"%s")
            echo "pod create time: $podCreateTimeStamp, base time: ${baseTime}"
            if [ ${podCreateTimeStamp} -gt ${baseTime} ]; then
                counter=$((counter + 1))
            fi
        done

        updatedPodNum=$counter
        echo "Number of new pod: ${updatedPodNum}"

        attempt=$((attempt + 1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ]; then
        echo_stderr "Failed to restart all weblogic server pods. "
        exit 1
    fi
}

# Call this function to make sure the lb service is avaliable.
function utility_waitfor_lb_svc_completed() {
    svcName=$1
    wlsDomainNS=$2
    perfSVCAttemps=$3
    perfRetryInterval=$4

    attempts=0
    svcState="running"
    while [ "$svcState" == "running" ] && [ $attempts -lt ${perfSVCAttemps} ]; do
        svcState="completed"
        attempts=$((attempts + 1))
        echo Waiting for job completed...${attempts}
        sleep ${perfRetryInterval}

        ip=$(kubectl get svc ${svcName} -n ${wlsDomainNS} -o json |
            jq '.status.loadBalancer.ingress[0].ip')
        echo "ip: ${ip}"
        if [[ "${ip}" == "null" ]]; then
            svcState="running"
        fi
    done

    if [ "$svcState" == "running" ] && [ $attempts -ge ${perfSVCAttemps} ]; then
        echo_stderr "Failed to create service: ${svcName}"
        exit 1
    fi
}

# Call this function to make sure the ingress is avaliable.
function utility_waitfor_ingress_completed() {
    svcName=$1
    wlsDomainNS=$2
    perfSVCAttemps=$3
    perfRetryInterval=$4

    attempts=0
    svcState="running"
    while [ "$svcState" == "running" ] && [ $attempts -lt ${perfSVCAttemps} ]; do
        svcState="completed"
        attempts=$((attempts + 1))
        echo Waiting for job completed...${attempts}
        sleep ${perfRetryInterval}

        ip=$(kubectl get ingress ${svcName} -n ${wlsDomainNS} -o json |
            jq '.status.loadBalancer.ingress[0].ip')
        echo "ip: ${ip}"
        if [[ "${ip}" == "null" ]]; then
            svcState="running"
        fi
    done

    if [ "$svcState" == "running" ] && [ $attempts -ge ${perfSVCAttemps} ]; then
        echo_stderr "Failed to create service: ${svcName}"
        exit 1
    fi
}
