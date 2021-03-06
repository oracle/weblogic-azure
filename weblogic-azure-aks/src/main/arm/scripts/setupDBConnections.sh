# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

# read <dbPassword> <wlsPassword> from stdin
function read_sensitive_parameters_from_stdin() {
    read dbPassword wlsPassword
}

#Function to display usage message
function usage() {
    usage=$(cat <<-END
Usage:
echo <dbPassword> <wlsPassword> |
    ./setupDBConnections.sh
    <aksClusterRGName>
    <aksClusterName>
    <databaseType>
    <dbUser>
    <dsConnectionURL>
    <jdbcDataSourceName>
    <wlsDomainUID>
    <wlsUser>
    <dbOptType>
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
    if [[ -z "$aksClusterRGName" || -z "${aksClusterName}" ]]; then
        echo_stderr "aksClusterRGName and aksClusterName are required. "
        usage 1
    fi

    if [ -z "$databaseType" ]; then
        echo_stderr "databaseType is required. "
        usage 1
    fi

    if [[ -z "$dbPassword" || -z "${dbUser}" ]]; then
        echo_stderr "dbPassword and dbUser are required. "
        usage 1
    fi

    if [ -z "$dsConnectionURL" ]; then
        echo_stderr "dsConnectionURL is required. "
        usage 1
    fi

    if [ -z "$jdbcDataSourceName" ]; then
        echo_stderr "jdbcDataSourceName is required. "
        usage 1
    fi

    if [ -z "$wlsDomainUID" ]; then
        echo_stderr "wlsDomainUID is required. "
        usage 1
    fi

    if [[ -z "$wlsUser" || -z "${wlsPassword}" ]]; then
        echo_stderr "wlsUser and wlsPassword are required. "
        usage 1
    fi
}

# Connect to AKS cluster
function connect_aks_cluster() {
    az aks get-credentials \
        --resource-group ${aksClusterRGName} \
        --name ${aksClusterName} \
        --overwrite-existing
}

function create_datasource_model_configmap_and_secret() {
    echo "get data source secret name"
    jndiLabel=${jdbcDataSourceName//\//\_}
    secretLen=$(kubectl get secret -n ${wlsDomainNS} -l datasource.JNDI="${jndiLabel}" -o json \
        | jq '.items | length')
    if [ ${secretLen} -ge 1 ];then
        dbSecretName=$(kubectl get secret -n ${wlsDomainNS} -l datasource.JNDI="${jndiLabel}" -o json \
            | jq ".items[0].metadata.name" \
            | tr -d "\"")
    else
        dbSecretName="ds-secret-${databaseType}-${datetime}"
    fi

    echo "Data source secret name: ${dbSecretName}"
    chmod ugo+x $scriptDir/dbUtility.sh
    echo "${dbPassword}" | \
        bash $scriptDir/dbUtility.sh \
        ${databaseType} \
        "${dbUser}" \
        "${dsConnectionURL}" \
        "${jdbcDataSourceName}" \
        "${wlsDomainUID}" \
        "${dbSecretName}" \
        "${optTypeUpdate}"
}

function apply_datasource_to_domain() {
    echo "apply datasoure"
    # get domain configurations
    domainConfigurationJsonFile=$scriptDir/domain.json
    kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json >${domainConfigurationJsonFile}

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
    kubectl -n ${wlsDomainNS} patch domain ${wlsDomainUID} \
        --type=json \
        -p '[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/configuration/model/configMap", "value":'${wlsConfigmapName}'}, {"op": "replace", "path": "/spec/configuration/secrets", "value": '${secretStrings}'}]'
}

function remove_datasource_from_domain() {
    echo "remove datasoure secret from domain configuration"
    # get domain configurations
    domainConfigurationJsonFile=$scriptDir/domain.json
    kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json >${domainConfigurationJsonFile}

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
    kubectl -n ${wlsDomainNS} patch domain ${wlsDomainUID} \
        --type=json \
        -p '[{"op": "replace", "path": "/spec/restartVersion", "value": "'${restartVersion}'" }, {"op": "replace", "path": "/spec/configuration/model/configMap", "value":'${wlsConfigmapName}'}, {"op": "replace", "path": "/spec/configuration/secrets", "value": '${secretStrings}'}]'
}

function wait_for_operation_completed() {
    # Make sure all of the pods are running.
    replicas=$(kubectl -n ${wlsDomainNS} get domain ${wlsDomainUID} -o json \
        | jq '. | .spec.clusters[] | .replicas')

    utility_wait_for_pod_restarted \
        ${timestampBeforePatchingDomain} \
        ${replicas} \
        ${wlsDomainUID} \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}

    utility_wait_for_pod_completed \
        ${replicas} \
        ${wlsDomainNS} \
        ${checkPodStatusMaxAttemps} \
        ${checkPodStatusInterval}
}

function delete_datasource() {
    echo "remove secret and model of data source ${jdbcDataSourceName}"
    # remove secret
    # remove model
    chmod ugo+x $scriptDir/dbUtility.sh
     echo "${dbPassword}" | \
        bash $scriptDir/dbUtility.sh \
        ${databaseType} \
        "${dbUser}" \
        "${dsConnectionURL}" \
        "${jdbcDataSourceName}" \
        "${wlsDomainUID}" \
        "${dbSecretName}" \
        "${optTypeDelete}"

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
connect('${wlsUser}', '${wlsPassword}', '${t3ConnectionString}')
serverRuntime()
print 'start to query data source jndi bean'
dsMBeans = cmo.getJDBCServiceRuntime().getJDBCDataSourceRuntimeMBeans()
ds_name = '${jdbcDataSourceName}'
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
        echo_stderr "Failed to configure datasource ${jdbcDataSourceName}. Please make sure the input values are correct."
        delete_datasource
        exit 1
    fi
}


# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

export aksClusterRGName=$1
export aksClusterName=$2
export databaseType=$3
export dbUser=$4
export dsConnectionURL=$5
export jdbcDataSourceName=$6
export wlsDomainUID=$7
export wlsUser=$8
export dbOptType=$9

export datetime=$(date +%s)
export optTypeDelete='delete'
export optTypeUpdate='createOrUpdate'
export wlsClusterName="cluster-1"
export wlsClusterSvcName="${wlsDomainUID}-cluster-${wlsClusterName}"
export wlsConfigmapName="${wlsDomainUID}-wdt-config-map"
export wlsDomainNS="${wlsDomainUID}-ns"

read_sensitive_parameters_from_stdin

validate_input

connect_aks_cluster

install_kubectl

if [[ "${dbOptType}" == "${optTypeDelete}" ]];then
    echo "delete date source: ${jdbcDataSourceName}"
    delete_datasource
else
    echo "create/update data source: ${jdbcDataSourceName}"
    create_datasource_model_configmap_and_secret
    apply_datasource_to_domain
    wait_for_operation_completed
    validate_datasource
fi
