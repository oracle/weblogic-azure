# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
#
# env inputs:
# AKS_CLUSTER_NAME
# AKS_CLUSTER_RESOURCEGROUP_NAME
# WLS_DOMAIN_UID

# Main script
echo "install kubectl"
az aks install-cli

echo "Connect AKS"
az aks get-credentials \
    --resource-group ${AKS_CLUSTER_RESOURCEGROUP_NAME} \
    --name ${AKS_CLUSTER_NAME} \
    --overwrite-existing

wlsDomainNS="${WLS_DOMAIN_UID}-ns"

domainConfigurationYaml=/tmp/domain.yaml
rm -f ${domainConfigurationYaml}
kubectl get domain ${WLS_DOMAIN_UID} -n ${wlsDomainNS} -o yaml >${domainConfigurationYaml}

adminPodName=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.serverName=admin-server -o json |
    jq '.items[0] | .metadata.name' |
    tr -d "\"")

if [ -z "${adminPodName}" ]; then
    echo >&2 "Fail to get admin server pod."
    exit 1
fi

echo "Copy model.yaml from /u01/wdt/models"
targetModelYaml=/tmp/model.yaml
rm -f ${targetModelYaml}
kubectl cp -n ${wlsDomainNS} -c weblogic-server ${adminPodName}:/u01/wdt/models/model.yaml ${targetModelYaml}
if [ $? != 0 ]; then
    echo >&2 "Fail to copy ${adminPodName}:/u01/wdt/models/model.yaml."
    exit 1
fi

echo "Copy model.properties from from /u01/wdt/models"
targetModelProperties=/tmp/model.properties
rm -f ${targetModelProperties}
kubectl cp -n ${wlsDomainNS} -c weblogic-server ${adminPodName}:/u01/wdt/models/model.properties ${targetModelProperties}
if [ $? != 0 ]; then
    echo >&2 "Fail to copy ${adminPodName}:/u01/wdt/models/model.properties."
    exit 1
fi

base64ofDomainYaml=$(cat ${domainConfigurationYaml} | base64)
base64ofModelYaml=$(cat ${targetModelYaml} | base64)
base64ofModelProperties=$(cat ${targetModelProperties} | base64)

result=$(jq -n -c \
    --arg domainDeploymentYaml "$base64ofDomainYaml" \
    --arg wlsImageModelYaml "$base64ofModelYaml" \
    --arg wlsImageProperties "$base64ofModelProperties" \
    '{domainDeploymentYaml: $domainDeploymentYaml, wlsImageModelYaml: $wlsImageModelYaml, wlsImageProperties: $wlsImageProperties}')
echo "result is: $result"
echo $result >$AZ_SCRIPTS_OUTPUT_PATH
