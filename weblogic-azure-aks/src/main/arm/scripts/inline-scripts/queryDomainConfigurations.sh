# Copyright (c) 2021, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
#
# env inputs:
# AKS_CLUSTER_NAME
# AKS_CLUSTER_RESOURCEGROUP_NAME
# WLS_CLUSTER_NAME
# WLS_DOMAIN_UID

# Main script
wlsContainerName="weblogic-server"

echo "install kubectl"
az aks install-cli

echo "Connect AKS"
connect_aks $AKS_CLUSTER_NAME $AKS_CLUSTER_RESOURCEGROUP_NAME

wlsDomainNS="${WLS_DOMAIN_UID}-ns"

domainConfigurationYaml=/tmp/domain.yaml
rm -f ${domainConfigurationYaml}
kubectl get domain ${WLS_DOMAIN_UID} -n ${wlsDomainNS} -o yaml >${domainConfigurationYaml}

podNum=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.clusterName=${WLS_CLUSTER_NAME} -o json | jq '.items| length')
    if [ ${podNum} -le 0 ]; then
        echo_stderr "Ensure your cluster has at least one pod."
        exit 1
    fi

podName=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.clusterName=${WLS_CLUSTER_NAME} -o json \
    | jq '.items[0] | .metadata.name' \
    | tr -d "\"")

echo "Copy model.yaml from /u01/wdt/models"
targetModelYaml=/tmp/model.yaml
rm -f ${targetModelYaml}
kubectl cp -n ${wlsDomainNS} -c ${wlsContainerName} ${podName}:/u01/wdt/models/model.yaml ${targetModelYaml}
if [ $? != 0 ]; then
    echo >&2 "Fail to copy ${podName}:/u01/wdt/models/model.yaml."
    exit 1
fi

echo "Copy model.properties from from /u01/wdt/models"
targetModelProperties=/tmp/model.properties
rm -f ${targetModelProperties}
kubectl cp -n ${wlsDomainNS} -c ${wlsContainerName} ${podName}:/u01/wdt/models/model.properties ${targetModelProperties}
if [ $? != 0 ]; then
    echo >&2 "Fail to copy ${podName}:/u01/wdt/models/model.properties."
    exit 1
fi

echo "Query WebLogic version and patch numbers"
targetFile4Versions=/tmp/version.info
kubectl exec -it ${podName} -n ${wlsDomainNS} -c ${wlsContainerName} \
    -- bash -c 'source $ORACLE_HOME/wlserver/server/bin/setWLSEnv.sh > /dev/null 2>&1 && java weblogic.version -verbose >"'${targetFile4Versions}'"'
if [ $? != 0 ]; then
    echo >&2 "Fail to run java weblogic.version."
    exit 1
fi
rm -f ${targetFile4Versions}
kubectl cp -n ${wlsDomainNS} -c ${wlsContainerName} ${podName}:${targetFile4Versions} ${targetFile4Versions}
if [ $? != 0 ]; then
    echo >&2 "Fail to copy ${podName}:${targetFile4Versions}."
    exit 1
fi

base64ofDomainYaml=$(cat ${domainConfigurationYaml} | base64)
base64ofModelYaml=$(cat ${targetModelYaml} | base64)
base64ofModelProperties=$(cat ${targetModelProperties} | base64)
base64ofWLSVersionDetails=$(cat ${targetFile4Versions} | base64)

result=$(jq -n -c \
    --arg domainDeploymentYaml "$base64ofDomainYaml" \
    --arg wlsImageModelYaml "$base64ofModelYaml" \
    --arg wlsImageProperties "$base64ofModelProperties" \
    --arg wlsVersionDetails "${base64ofWLSVersionDetails}" \
    '{domainDeploymentYaml: $domainDeploymentYaml, wlsImageModelYaml: $wlsImageModelYaml, wlsImageProperties: $wlsImageProperties, wlsVersionDetails: $wlsVersionDetails}')
echo "result is: $result"
echo $result >$AZ_SCRIPTS_OUTPUT_PATH
