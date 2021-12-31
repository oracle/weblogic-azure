# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
#
# env inputs:
# AKS_CLUSTER_NAME
# AKS_CLUSTER_RESOURCEGROUP_NAME
# WLS_DOMAIN_UID

# Main script
script="${BASH_SOURCE[0]}"
scriptDir="$(cd "$(dirname "${script}")" && pwd)"
source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

qualityofService="BestEffort"
wlsDomainNS="${WLS_DOMAIN_UID}-ns"

echo_stdout "install kubectl"
install_kubectl

echo_stdout "Connect to AKS"
az aks get-credentials \
    --resource-group ${AKS_CLUSTER_RESOURCEGROUP_NAME} \
    --name ${AKS_CLUSTER_NAME} \
    --overwrite-existing

# get name of the running admin pod
adminPodName=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.serverName=admin-server -o json |
    jq '.items[0] | .metadata.name' |
    tr -d "\"")
if [ -z "${adminPodName}" ]; then
    echo_stderr "Fail to get admin server pod."
    exit 1
fi

# run `source $ORACLE_HOME/wlserver/server/bin/setWLSEnv.sh > /dev/null 2>&1 && java weblogic.version` to get the version.
# the command will print three lines, with WLS version in the first line.
# use `grep "WebLogic Server" to get the first line.

# $ source $ORACLE_HOME/wlserver/server/bin/setWLSEnv.sh > /dev/null 2>&1 && java weblogic.version
# WebLogic Server 12.2.1.4.0 Thu Sep 12 04:04:29 GMT 2019 1974621
# Use 'weblogic.version -verbose' to get subsystem information
# Use 'weblogic.utils.Versions' to get version information for all modules
rawOutput=$(kubectl exec -it ${adminPodName} -n ${wlsDomainNS} -c ${wlsContainerName} \
    -- bash -c 'source $ORACLE_HOME/wlserver/server/bin/setWLSEnv.sh > /dev/null 2>&1 && java weblogic.version | grep "WebLogic Server"')

# get version from string like "WebLogic Server 12.2.1.4.0 Thu Sep 12 04:04:29 GMT 2019 1974621"
stringArray=($rawOutput)
version=${stringArray[2]}
echo_stdout "WebLogic Server version: ${version}"

if [ "${version#*14.1.1.0}" != "$version" ]; then
    timestampBeforePatchingDomain=$(date +%s)
    echo  "timestampBeforePatchingDomain=${timestampBeforePatchingDomain}"
    
    # we assume the customer to create WebLogic Server using the offer or template,
    # and specify the same resources requirement for admin server and managed server.
    cpuRequest=$(kubectl get domain ${WLS_DOMAIN_UID} -n ${wlsDomainNS} -o json |
        jq '. |.spec.serverPod.resources.requests.cpu' |
        tr -d "\"")
    echo_stdout "Previous CPU request: ${cpuRequest}"

    memoryRequest=$(kubectl get domain ${WLS_DOMAIN_UID} -n ${wlsDomainNS} -o json |
        jq '. | .spec.serverPod.resources.requests.memory' |
        tr -d "\"")
    echo_stdout "Previous memory request: ${memoryRequest}"

    restartVersion=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json |
        jq '. | .spec.restartVersion' |
        tr -d "\"")
    restartVersion=$((restartVersion+1))

    # check CPU units, set units with "m"
    if [[ ${cpuRequest} =~ "m" ]]; then
        cpu=$(echo $cpuRequest | sed 's/[^0-9]*//g')
    else
        cpu=$((cpuRequest * 1000))
    fi
    # make sure there is enough CPU limits to run the WebLogic Server
    # if the cpu is less than 500m, set it 500m
    # the domain configuration will be outputed after the offer deployment finishes.
    if [ $cpu -lt 500 ]; then
        cpu=500
    fi

    # create patch configuration with YAML file
    # keep resources.limits the same with requests
    cat <<EOF >patch-resource-limits.yaml
spec:
  serverPod:
    resources: 
      requests:
        cpu: "${cpu}m"
        memory: "${memoryRequest}"
      limits:
        cpu: "${cpu}m"
        memory: "${memoryRequest}"
  configuration: 
    introspectorJobActiveDeadlineSeconds: ${constIntrospectorJobActiveDeadlineSeconds}
  restartVersion: "${restartVersion}"
EOF
    echo_stdout "New resource configurations: "
    echo_stdout $(cat patch-resource-limits.yaml)
    # patch the domain with resource limits
    kubectl -n ${wlsDomainNS} patch domain ${WLS_DOMAIN_UID} \
        --type=merge \
        --patch "$(cat patch-resource-limits.yaml)"

    # make sure all of the pods are running correctly.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json |
        jq '. | .spec.clusters[] | .replicas')
    # pod provision will be slower, set larger max attemp.
    maxAttemps=$((checkPodStatusMaxAttemps * 2))
    interval=$((checkPodStatusInterval * 2))

    utility_wait_for_pod_restarted \
        ${timestampBeforePatchingDomain} \
        ${replicas} \
        "${WLS_DOMAIN_UID}" \
        ${maxAttemps} \
        ${interval}

    qualityofService="Guaranteed"
fi

# output the WebLogic Server version and quality of service.
result=$(jq -n -c \
    --arg wlsVersion "$version" \
    --arg qualityofService "$qualityofService" \
    '{wlsVersion: $wlsVersion, qualityofService: $qualityofService}')
echo "result is: $result"
echo $result >$AZ_SCRIPTS_OUTPUT_PATH
