# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

echo "Script ${0} starts"

function generate_ds_model() {
    databaseDriver=${driverOracle}
    databaseTestTableName=${testTableOracle}
    if [[ "${DATABASE_TYPE}" == "${dbTypePostgre}" ]]; then
        databaseDriver=${driverPostgre}
        databaseTestTableName=${testTablePostgre}
    elif [[ "${DATABASE_TYPE}" == "${dbTypeSQLServer}" ]]; then
        databaseDriver=${driverSQLServer}
        databaseTestTableName=${testTableSQLServer}
    elif [[ "${DATABASE_TYPE}" == "${dbTypeMySQL}" ]]; then
        databaseDriver=${driverMySQL}
        databaseTestTableName=${testTableMySQL}

        if [[ "${ENABLE_PASSWORDLESS_CONNECTION,,}" == "true" ]]; then
            databaseDriver=${driverMySQLCj}
        fi
    elif [[ "${DATABASE_TYPE}" == "${dbTypeOthers}" ]]; then
        databaseDriver=${DB_DRIVER_NAME}
        databaseTestTableName=${TEST_TABLE_NAME}
    fi

    echo "generate data source model file"
    chmod ugo+x $scriptDir/genDatasourceModel.sh
    dsModelFilePath=$scriptDir/${dbSecretName}.yaml
    bash $scriptDir/genDatasourceModel.sh \
        ${dsModelFilePath} \
        "${JDBC_DATASOURCE_NAME}" \
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
    jndiLabel=${JDBC_DATASOURCE_NAME//\//\_}
    secretLen=$(kubectl get secret -n ${domainNamespace} -l datasource.JNDI="${jndiLabel}" -o json |
        jq '.items | length')
    if [ ${secretLen} -ge 1 ]; then
        echo "secret for ${JDBC_DATASOURCE_NAME} exists"
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

    echo "create/update secret ${dbSecretName} for ${JDBC_DATASOURCE_NAME}"
    kubectl -n ${domainNamespace} create secret generic \
        ${dbSecretName} \
        --from-literal=password="${DB_PASSWORD}" \
        --from-literal=url="${DB_CONNECTION_STRING}" \
        --from-literal=user="${DB_USER}"

    kubectl -n sample-domain1-ns label secret \
        ${dbSecretName} \
        weblogic.domainUID=${WLS_DOMAIN_UID} \
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
        weblogic.domainUID=${WLS_DOMAIN_UID}
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
        weblogic.domainUID=${WLS_DOMAIN_UID}
}

# Main script
set -Eo pipefail

export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

export dbSecretName=$1
export operationType=$2

export domainNamespace=${WLS_DOMAIN_UID}-ns
export clusterName="cluster-1"
export dbTypeOracle="oracle"
export dbTypePostgre="postgresql"
export dbTypeSQLServer="sqlserver"
export dbTypeMySQL='mysql'
export dbTypeOthers="otherdb"
export driverOracle="oracle.jdbc.OracleDriver"
export driverPostgre="org.postgresql.Driver"
export driverSQLServer="com.microsoft.sqlserver.jdbc.SQLServerDriver"
export driverMySQL="com.mysql.jdbc.Driver"
export driverMySQLCj="com.mysql.cj.jdbc.Driver"
export optTypeDelete='delete'
export testTableOracle="SQL ISVALID"
export testTablePostgre="SQL SELECT 1"
export testTableSQLServer="SQL SELECT 1"
export testTableMySQL="SQL SELECT 1"
export wlsConfigmapName="${WLS_DOMAIN_UID}-wdt-config-map"

if [[ "${operationType}" == "${optTypeDelete}" ]]; then
    delete_model_and_secret
else
    generate_ds_model
    update_configmap
    create_datasource_secret
fi
