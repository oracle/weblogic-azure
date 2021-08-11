# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Alpine Linux

function install_jdk() {
    # Install Microsoft OpenJDK
    apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

    echo "java version"
    java -version
    if [ $? -eq 1 ]; then
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
        echo "Failed to install kubectl."
        exit 1
    fi
}

#Function to output message to stdout
function echo_stderr() {
    echo "$@" >&2
    echo "$@" >>stdout
}

function echo_stdout() {
    echo "$@"
    echo "$@" >>stdout
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

    echo "Waiting for $((appReplicas+1)) pods are running."

    readyPodNum=0
    attempt=0
    while [[ ${readyPodNum} -le  ${appReplicas} && $attempt -le ${checkPodStatusMaxAttemps} ]];do
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json \
            | jq '.items[] | .status.phase' \
            | grep "Running")
        if [ -z "${ret}" ];then
            readyPodNum=0
        else
            readyPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json \
                | jq '.items[] | .status.phase' \
                | grep -c "Running")
        fi
        echo "Number of new running pod: ${readyPodNum}"
        attempt=$((attempt+1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ];then
        echo "It takes too long to wait for all the pods are running, please refer to http://oracle.github.io/weblogic-kubernetes-operator/samples/simple/azure-kubernetes-service/#troubleshooting"
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

    echo "Waiting for $((appReplicas+1)) new pods created with image ${acrImagePath}"
    
    updatedPodNum=0
    attempt=0
    while [ ${updatedPodNum} -le  ${appReplicas} ] && [ $attempt -le ${checkPodStatusMaxAttemps} ];do
        echo "attempts ${attempt}"
        ret=$(kubectl get pods -n ${wlsDomainNS} -o json \
            | jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' \
            | grep "${acrImagePath}")
    
        if [ -z "${ret}" ];then
            updatedPodNum=0
        else
            updatedPodNum=$(kubectl get pods -n ${wlsDomainNS} -o json \
                | jq '.items[] | .spec | .containers[] | select(.name == "weblogic-server") | .image' \
                | grep -c "${acrImagePath}")
        fi
        echo "Number of new pod: ${updatedPodNum}"

        attempt=$((attempt+1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ];then
        echo "Failed to update image ${acrImagePath} to all weblogic server pods. "
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
    while [ ${updatedPodNum} -le  ${appReplicas} ] && [ $attempt -le ${checkPodStatusMaxAttemps} ];do
        echo "attempts ${attempt}"
        ret=$(kubectl get pods -n ${wlsDomainNS} -l weblogic.domainUID=${wlsDomainUID} -o json \
            | jq '.items[] | .metadata.creationTimestamp' | tr -d "\"")
        
        counter=0
        for item in $ret; do
            # conver the time format from YYYY-MM-DDThh:mm:ssZ to YYYY.MM.DD-hh:mm:ss
            alpineItem=$(echo "${item}" | sed -e "s/-/./g;s/T/-/g;s/Z//g")
            podCreateTimeStamp=$(date -u -d "${alpineItem}" +"%s")
            echo "pod create time: $podCreateTimeStamp, base time: ${baseTime}"
            if [ ${podCreateTimeStamp} -gt ${baseTime} ]; then
                counter=$((counter+1))
            fi
        done

        updatedPodNum=$counter
        echo "Number of new pod: ${updatedPodNum}"

        attempt=$((attempt+1))
        sleep ${checkPodStatusInterval}
    done

    if [ ${attempt} -gt ${checkPodStatusMaxAttemps} ];then
        echo "Failed to restart all weblogic server pods. "
        exit 1
    fi
}