# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

# read <dbPassword> from stdin
function read_sensitive_parameters_from_stdin() {
    read dbPassword
}

function generate_ds_model() {
    databaseDriver=${driverOracle}
    databaseTestTableName=${testTableOracle}
    if [[ "${databaseType}" == "${dbTypePostgre}" ]]; then
        databaseDriver=${driverPostgre}
        databaseTestTableName=${testTablePostgre}
    elif [[ "${databaseType}" == "${dbTypeSQLServer}" ]]; then
        databaseDriver=${driverSQLServer}
        databaseTestTableName=${testTableSQLServer}
    fi

    echo "generate data source model file"
    chmod ugo+x $scriptDir/genDatasourceModel.sh
    dsModelFilePath=$scriptDir/${dbSecretName}.yaml
    bash $scriptDir/genDatasourceModel.sh \
        ${dsModelFilePath} \
        "${jdbcDataSourceName}" \
        "${clusterName}" \
        "${databaseDriver}" \
        "${databaseTestTableName}" \
        "${dbSecretName}"
}

function export_models_and_delete_configmap() {
    # create folder to store model files
    modelFilePath=$scriptDir/models
    if [ -d "${modelFilePath}" ]; then
        rm ${modelFilePath} -f -r
    fi

    mkdir ${modelFilePath}

    echo "check if configmap ${wlsConfigmapName} exists"
    ret=$(kubectl -n ${domainNamespace} get configmap | grep "${wlsConfigmapName}")
    if [ -n "${ret}" ]; then
        echo "configmap ${wlsConfigmapName} exists, update it with the datasource model."
        export wlsConfigmap=${scriptDir}/wdtconfigmap.json
        rm -f ${scriptDir}/wdtconfigmap.json
        kubectl -n ${domainNamespace} get configmap ${wlsConfigmapName} -o json >${wlsConfigmap}

        echo "query model keys"
        keyList=$(cat ${wlsConfigmap} | jq '.data | keys[]' | tr -d "\"")
        for item in $keyList; do
            echo "key: $item"
            if [[ "${item}" == "${dbSecretName}.yaml" ]]; then
                continue
            fi

            data=$(cat ${wlsConfigmap} | jq ".data[\"${item}\"]")
            data=$(echo "${data:1:${#data}-2}")
            echo -e "${data}" >${modelFilePath}/${item}
        done

        # remove current configmap and create a new one
        kubectl -n ${domainNamespace} delete configmap ${wlsConfigmapName}
    fi
}

function cleanup_secret_and_model() {
    echo "check if the datasource secret exists"
    jndiLabel=${jdbcDataSourceName//\//\_}
    secretLen=$(kubectl get secret -n ${domainNamespace} -l datasource.JNDI="${jndiLabel}" -o json |
        jq '.items | length')
    if [ ${secretLen} -ge 1 ]; then
        echo "secret for ${jdbcDataSourceName} exists"
        # delete the secrets
        index=0
        while [ $index -lt ${secretLen} ]; do
            # get secret name
            secretName=$(kubectl get secret -n ${domainNamespace} -l datasource.JNDI="${jndiLabel}" -o json |
                jq ".items[$index].metadata.name" |
                tr -d "\"")
            # remove the secret
            kubectl delete secret ${secretName} -n ${domainNamespace}
            # remove model if there is.
            rm -f ${modelFilePath}/${secretName}.yaml

            index=$((index + 1))
        done
    fi
}

function create_datasource_secret() {
    cleanup_secret_and_model

    echo "create/update secret ${dbSecretName} for ${jdbcDataSourceName}"
    kubectl -n ${domainNamespace} create secret generic \
        ${dbSecretName} \
        --from-literal=password="${dbPassword}" \
        --from-literal=url="${dsConnectionURL}" \
        --from-literal=user="${dbUser}"

    kubectl -n sample-domain1-ns label secret \
        ${dbSecretName} \
        weblogic.domainUID=${wlsDomainUID} \
        datasource.JNDI="${jndiLabel}"
}

function update_configmap() {
    echo "output all the models from configmap"
    export_models_and_delete_configmap
    # remove existing model if there is
    rm -f ${modelFilePath}/${dbSecretName}.yaml
    # copy the new model to model folder
    cp ${dsModelFilePath} ${modelFilePath}/${dbSecretName}.yaml

    echo "update configmap"
    kubectl -n ${domainNamespace} create configmap ${wlsConfigmapName} \
        --from-file=${modelFilePath}
    kubectl -n ${domainNamespace} label configmap ${wlsConfigmapName} \
        weblogic.domainUID=${wlsDomainUID}
}

function delete_model_and_secret() {
    # delete db models and secrets for the specified jndi name.
    echo "output all the models from configmap"
    export_models_and_delete_configmap

    cleanup_secret_and_model

    echo "update configmap"
    kubectl -n ${domainNamespace} create configmap ${wlsConfigmapName} \
        --from-file=${modelFilePath}
    kubectl -n ${domainNamespace} label configmap ${wlsConfigmapName} \
        weblogic.domainUID=${wlsDomainUID}
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

export databaseType=$1
export dbUser=$2
export dsConnectionURL=$3
export jdbcDataSourceName=$4
export wlsDomainUID=$5
export dbSecretName=$6
export operationType=$7

export domainNamespace=${wlsDomainUID}-ns
export clusterName="cluster-1"
export dbTypeOracle="oracle"
export dbTypePostgre="postgresql"
export dbTypeSQLServer="sqlserver"
export driverOracle="oracle.jdbc.OracleDriver"
export driverPostgre="org.postgresql.Driver"
export driverSQLServer="com.microsoft.sqlserver.jdbc.SQLServerDriver"
export optTypeDelete='delete'
export testTableOracle="SQL ISVALID"
export testTablePostgre="SQL SELECT 1"
export testTableSQLServer="SQL SELECT 1"
export wlsConfigmapName="${wlsDomainUID}-wdt-config-map"

read_sensitive_parameters_from_stdin

if [[ "${operationType}" == "${optTypeDelete}" ]]; then
    delete_model_and_secret
else
    generate_ds_model
    update_configmap
    create_datasource_secret
fi
