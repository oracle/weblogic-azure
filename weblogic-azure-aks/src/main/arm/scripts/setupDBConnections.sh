# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
You must specify the following environment variables:
AKS_RESOURCE_GROUP_NAME: the name of resource group that runs the AKS cluster.
AKS_NAME: the name of the AKS cluster.
DATABASE_TYPE: one of the supported database types.
DB_CONFIGURATION_TYPE: createOrUpdate: create a new data source connection, or update an existing data source connection. delete: delete an existing data source connection.
DB_PASSWORD: password for Database.
DB_USER: user id of Database.
DB_CONNECTION_STRING: JDBC Connection String.
DB_DRIVER_NAME: datasource driver name, must be specified if database type is otherdb.
GLOBAL_TRANSATION_PROTOCOL: Determines the transaction protocol (global transaction processing behavior) for the data source.
JDBC_DATASOURCE_NAME: JNDI Name for JDBC Datasource.
TEST_TABLE_NAME: the name of the database table to use when testing physical database connections. This name is required when you specify a Test Frequency and enable Test Reserved Connections.
WLS_DOMAIN_UID: UID of WebLogic domain, used in WebLogic Operator.
WLS_DOMAIN_USER: user name for WebLogic Administrator.
WLS_DOMAIN_PASSWORD: passowrd for WebLogic Administrator.
END
)

    echo_stdout "${usage}"
    if [ $1 -eq 1 ]; then
        echo_stderr "${usage}"
        exit 1
    fi
}

#Function to validate input
function validate_input() {
    if [[ -z "$AKS_RESOURCE_GROUP_NAME" || -z "${AKS_NAME}" ]]; then
        echo_stderr "AKS_RESOURCE_GROUP_NAME and AKS_NAME are required. "
        usage 1
    fi

    if [ -z "$DATABASE_TYPE" ]; then
        echo_stderr "DATABASE_TYPE is required. "
        usage 1
    fi

    if [ -z "${DB_USER}" ]; then
        echo_stderr "DB_USER are required. "
        usage 1
    fi

    if [ -z "$DB_CONNECTION_STRING" ]; then
        echo_stderr "DB_CONNECTION_STRING is required. "
        usage 1
    fi

    if [ -z "$JDBC_DATASOURCE_NAME" ]; then
        echo_stderr "JDBC_DATASOURCE_NAME is required. "
        usage 1
    fi

    if [ -z "$WLS_DOMAIN_UID" ]; then
        echo_stderr "WLS_DOMAIN_UID is required. "
        usage 1
    fi

    if [[ -z "$WLS_DOMAIN_USER" || -z "${WLS_DOMAIN_PASSWORD}" ]]; then
        echo_stderr "WLS_DOMAIN_USER and WLS_DOMAIN_PASSWORD are required. "
        usage 1
    fi
}

# Connect to AKS cluster
function connect_aks_cluster() {
    az aks get-credentials \
        --resource-group ${AKS_RESOURCE_GROUP_NAME} \
        --name ${AKS_NAME} \
        --overwrite-existing
}

function create_datasource_model_configmap_and_secret() {
    echo "get data source secret name"
    jndiLabel=${JDBC_DATASOURCE_NAME//\//\_}
    secretLen=$(kubectl get secret -n ${wlsDomainNS} -l datasource.JNDI="${jndiLabel}" -o json \
        | jq '.items | length')
    if [ ${secretLen} -ge 1 ];then
        dbSecretName=$(kubectl get secret -n ${wlsDomainNS} -l datasource.JNDI="${jndiLabel}" -o json \
            | jq ".items[0].metadata.name" \
            | tr -d "\"")
    else
        dbSecretName="ds-secret-${DATABASE_TYPE}-${datetime}"
    fi

    echo "Data source secret name: ${dbSecretName}"
    chmod ugo+x $scriptDir/dbUtility.sh
    bash $scriptDir/dbUtility.sh ${dbSecretName} ${optTypeUpdate}
}

function apply_datasource_to_domain() {
    echo "apply datasoure"
    # get domain configurations
    domainConfigurationJsonFile=$scriptDir/domain.json
    kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json >${domainConfigurationJsonFile}

    restartVersion=$(cat ${domainConfigurationJsonFile} | jq '. | .spec.restartVersion' | tr -d "\"")
    secretList=$(cat ${domainConfigurationJsonFile} | jq -r '. | .spec.configuration.secrets')
    restartVersion=$((restartVersion+1))

    echo "current secrets: ${secretList}"
    if [[ "${secretList}" != "null" ]];then
        secretList=$(cat ${domainConfigurationJsonFile} | jq -r '. | .spec.configuration.secrets[]')
        secretStrings="["
        for item in $secretList; do
            if [[ "${item}" == "${dbSecretName}" ]]; then
                continue
            fi
            secretStrings="${secretStrings}\"${item}\","
        done

        secretStrings="${secretStrings}\"${dbSecretName}\"]"
    else
        secretStrings="[\"${dbSecretName}\"]"
    fi

    echo "secrets: ${secretStrings}"

    # apply the configmap
    # apply the secret
    # restart the domain
    timestampBeforePatchingDomain=$(date +%s)
    kubectl -n ${wlsDomainNS} patch domain ${WLS_DOMAIN_UID} \
        --type=json \
        -p '[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/configuration/model/configMap", "value":'${wlsConfigmapName}'}, {"op": "replace", "path": "/spec/configuration/secrets", "value": '${secretStrings}'}]'
}

function remove_datasource_from_domain() {
    echo "remove datasoure secret from domain configuration"
    # get domain configurations
    domainConfigurationJsonFile=$scriptDir/domain.json
    kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json >${domainConfigurationJsonFile}

    restartVersion=$(cat ${domainConfigurationJsonFile} | jq '. | .spec.restartVersion' | tr -d "\"")
    secretList=$(cat ${domainConfigurationJsonFile} | jq -r '. | .spec.configuration.secrets')
    restartVersion=$((restartVersion+1))

    echo "current secrets: ${secretList}"
    if [[ "${secretList}" != "null" ]];then
        secretList=$(cat ${domainConfigurationJsonFile} | jq -r '. | .spec.configuration.secrets[]')
        secretStrings="["
        index=0;
        for item in $secretList; do
            ret=$(kubectl -n ${wlsDomainNS} get secret | grep "${item}")
            # the secret should have been deleted.
            if [ -z "${ret}" ]; then
                continue
            fi

            secretStrings="${secretStrings}\"${item}\","
            index=$((index+1))
        done

        if [ $index -ge 1 ]; then
            # remove the last comma
            secretStrings=$(echo "${secretStrings:0:${#secretStrings}-1}")
        fi

        secretStrings="${secretStrings}]"
    else
        secretStrings="[]"
    fi

    echo "secrets: ${secretStrings}"

    # apply the configmap
    # apply the secret
    # restart the domain
    timestampBeforePatchingDomain=$(date +%s)
    kubectl -n ${wlsDomainNS} patch domain ${WLS_DOMAIN_UID} \
        --type=json \
        -p '[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/configuration/model/configMap", "value":'${wlsConfigmapName}'}, {"op": "replace", "path": "/spec/configuration/secrets", "value": '${secretStrings}'}]'
}

function wait_for_operation_completed() {
    # Make sure all of the pods are running.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json \
        | jq '. | .spec.clusters[] | .replicas')

    utility_wait_for_pod_restarted \
        ${timestampBeforePatchingDomain} \
        ${replicas} \
        ${WLS_DOMAIN_UID} \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}

    utility_wait_for_pod_completed \
        ${replicas} \
        ${wlsDomainNS} \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function delete_datasource() {
    echo "remove secret and model of data source ${JDBC_DATASOURCE_NAME}"
    # remove secret
    # remove model
    chmod ugo+x $scriptDir/dbUtility.sh
    bash $scriptDir/dbUtility.sh ${dbSecretName} ${optTypeDelete}

    # update weblogic domain
    remove_datasource_from_domain

    wait_for_operation_completed
}

function validate_datasource() {
    dsScriptFileName=get-datasource-status.py
    testDatasourceScript=${scriptDir}/${dsScriptFileName}
    podNum=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.clusterName=${wlsClusterName} -o json | jq '.items| length')
    if [ ${podNum} -le 0 ]; then
        echo_stderr "Ensure your cluster has at least one pod."
        exit 1
    fi

    podName=$(kubectl -n ${wlsDomainNS} get pod -l weblogic.clusterName=${wlsClusterName} -o json \
        | jq '.items[0] | .metadata.name' \
        | tr -d "\"")

    # get non-ssl port
    clusterTargetPort=$(kubectl get svc ${wlsClusterSvcName} -n ${wlsDomainNS} -o json | jq '.spec.ports[] | select(.name=="default") | .port')
    t3ConnectionString="t3://${wlsClusterSvcName}.${wlsDomainNS}.svc.cluster.local:${clusterTargetPort}"
    cat <<EOF >${testDatasourceScript}
connect('${WLS_DOMAIN_USER}', '${WLS_DOMAIN_PASSWORD}', '${t3ConnectionString}')
serverRuntime()
print 'start to query data source jndi bean'
dsMBeans = cmo.getJDBCServiceRuntime().getJDBCDataSourceRuntimeMBeans()
ds_name = '${JDBC_DATASOURCE_NAME}'
for ds in dsMBeans:
    if (ds_name == ds.getName()):
        print 'DS name is: '+ds.getName()
        print 'State is ' +ds.getState()
EOF

    echo "copy test script ${testDatasourceScript} to pod path /tmp/${dsScriptFileName}"
    targetDSFilePath=/tmp/${dsScriptFileName}
    kubectl cp ${testDatasourceScript} -n ${wlsDomainNS} ${podName}:${targetDSFilePath}
    kubectl exec -it ${podName} -n ${wlsDomainNS} -c ${wlsContainerName} -- bash -c "wlst.sh ${targetDSFilePath}" | grep "State is Running"
    
    if [ $? == 1 ];then
        echo_stderr "Failed to configure datasource ${JDBC_DATASOURCE_NAME}. Please make sure the input values are correct."
        delete_datasource
        exit 1
    fi
}


# Main script
set -Eo pipefail

export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

export datetime=$(date +%s)
export optTypeDelete='delete'
export optTypeUpdate='createOrUpdate'
export wlsClusterName="cluster-1"
export wlsClusterSvcName="${WLS_DOMAIN_UID}-cluster-${wlsClusterName}"
export wlsConfigmapName="${WLS_DOMAIN_UID}-wdt-config-map"
export wlsDomainNS="${WLS_DOMAIN_UID}-ns"

validate_input

connect_aks_cluster

install_kubectl

if [[ "${DB_CONFIGURATION_TYPE}" == "${optTypeDelete}" ]];then
    echo "delete date source: ${JDBC_DATASOURCE_NAME}"
    delete_datasource
else
    echo "create/update data source: ${JDBC_DATASOURCE_NAME}"
    create_datasource_model_configmap_and_secret
    apply_datasource_to_domain
    wait_for_operation_completed
    validate_datasource
fi
