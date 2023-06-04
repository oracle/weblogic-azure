# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

export filePath=$1
export wlsImagePath=$2
export javaOptions=$3

export adminServiceUrl="${WLS_DOMAIN_UID}-admin-server.${WLS_DOMAIN_UID}-ns.svc.cluster.local"
export clusterServiceUrl="${WLS_DOMAIN_UID}-cluster-${constClusterName}.${WLS_DOMAIN_UID}-ns.svc.cluster.local"
export wlsDomainNS="${WLS_DOMAIN_UID}-ns"

# output the existing domain configuration
export previousConfig=${scriptDir}/previousDomain.json
kubectl -n ${wlsDomainNS} get domain ${WLS_DOMAIN_UID} -o json >${previousConfig}

# query logHomeEnabled
logHomeEnabled=$(cat ${previousConfig} | jq '. | .spec.logHomeEnabled')
logHome=$(cat ${previousConfig} | jq '. | .spec.logHome')
envList=$(cat ${previousConfig} | jq '. | .spec.serverPod.env')
envLength=$(cat ${previousConfig} | jq '. | .spec.serverPod.env | length')
restartVersion=$(cat ${previousConfig} | jq '. | .spec.restartVersion' | tr -d "\"")
configMap=$(cat ${previousConfig} | jq '. | .spec.configuration.model.configMap')
secretList=$(cat ${previousConfig} | jq '. | .spec.configuration.secrets')
restartVersion=$((restartVersion+1))

cat <<EOF >$filePath
# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
# Based on ./kubernetes/samples/scripts/create-weblogic-domain/model-in-image/domain-resources/WLS/mii-initial-d1-WLS-v1.yaml
# in https://github.com/oracle/weblogic-kubernetes-operator.
# This is an example of how to define a Domain resource.
#
apiVersion: "weblogic.oracle/v9"
kind: Domain
metadata:
  name: "${WLS_DOMAIN_UID}"
  namespace: "${wlsDomainNS}"
  labels:
    weblogic.domainUID: "${WLS_DOMAIN_UID}"

spec:
  # Set to 'FromModel' to indicate 'Model in Image'.
  domainHomeSourceType: FromModel

  # The WebLogic Domain Home, this must be a location within
  # the image for 'Model in Image' domains.
  domainHome: /u01/domains/${WLS_DOMAIN_UID}

  # The WebLogic Server Docker image that the Operator uses to start the domain
  image: "${wlsImagePath}"

  # Defaults to "Always" if image tag (version) is ':latest'
  imagePullPolicy: "IfNotPresent"

  # Identify which Secret contains the credentials for pulling an image
  imagePullSecrets:
  - name: regsecret
  
  # Identify which Secret contains the WebLogic Admin credentials,
  # the secret must contain 'username' and 'password' fields.
  webLogicCredentialsSecret: 
    name: "${WLS_DOMAIN_UID}-weblogic-credentials"

  # Whether to include the WebLogic Server stdout in the pod's stdout, default is true
  includeServerOutInPodLog: true
  # Set which WebLogic Servers the Operator will start
  # - "NEVER" will not start any server in the domain
  # - "ADMIN_ONLY" will start up only the administration server (no managed servers will be started)
  # - "IF_NEEDED" will start all non-clustered servers, including the administration server, and clustered servers up to their replica count.
  serverStartPolicy: "IF_NEEDED"
EOF

if [[ "${logHomeEnabled}" == "true" ]];then
  cat <<EOF >>$filePath
  # Whether to enable overriding your log file location, see also 'logHome'
  logHomeEnabled: true
  
  # The location for domain log, server logs, server out, introspector out, and Node Manager log files
  # see also 'logHomeEnabled', 'volumes', and 'volumeMounts'.
  logHome: ${logHome}
EOF
fi

# Resources
cat <<EOF >>$filePath
  # Settings for all server pods in the domain including the introspector job pod
  serverPod:
    resources:
      requests:
        cpu: "${WLS_RESOURCE_REQUEST_CPU}"
        memory: "${WLS_RESOURCE_REQUEST_MEMORY}"
    # Optional new or overridden environment variables for the domain's pods
    # - This sample uses CUSTOM_DOMAIN_NAME in its image model file 
    #   to set the Weblogic domain name
    env:
EOF

if [[ "${ENABLE_CUSTOM_SSL,,}" == "true" ]]; then
  cat <<EOF >>$filePath
    - name: SSL_IDENTITY_PRIVATE_KEY_ALIAS
      valueFrom:
        secretKeyRef:
          key: sslidentitykeyalias
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_IDENTITY_PRIVATE_KEY_PSW
      valueFrom:
        secretKeyRef:
          key: sslidentitykeypassword
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_IDENTITY_PRIVATE_KEYSTORE_PATH
      valueFrom:
        secretKeyRef:
          key: sslidentitystorepath
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_IDENTITY_PRIVATE_KEYSTORE_TYPE
      valueFrom:
        secretKeyRef:
          key: sslidentitystoretype
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_IDENTITY_PRIVATE_KEYSTORE_PSW
      valueFrom:
        secretKeyRef:
          key: sslidentitystorepassword
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_TRUST_KEYSTORE_PATH
      valueFrom:
        secretKeyRef:
          key: ssltruststorepath
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_TRUST_KEYSTORE_TYPE
      valueFrom:
        secretKeyRef:
          key: ssltruststoretype
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
    - name: SSL_TRUST_KEYSTORE_PSW
      valueFrom:
        secretKeyRef:
          key: ssltruststorepassword
          name: ${WLS_DOMAIN_UID}-weblogic-ssl-credentials
EOF
fi

if [[ "${ENABLE_ADMIN_CUSTOM_T3,,}" == "true" ]]; then
  cat <<EOF >>$filePath
    - name: T3_TUNNELING_ADMIN_PORT
      value: "${WLS_T3_ADMIN_PORT}"
    - name: T3_TUNNELING_ADMIN_ADDRESS
      value: "${adminServiceUrl}"
EOF
fi

if [[ "${ENABLE_CLUSTER_CUSTOM_T3,,}" == "true" ]]; then
  cat <<EOF >>$filePath
    - name: T3_TUNNELING_CLUSTER_PORT
      value: "${WLS_T3_CLUSTER_PORT}"
    - name: T3_TUNNELING_CLUSTER_ADDRESS
      value: "${clusterServiceUrl}"
EOF
fi

index=0
while [ $index -lt ${envLength} ]; do
    envItemName=$(cat ${previousConfig} | jq ". | .spec.serverPod.env[$index] | .name" | tr -d "\"")
    envItemValue=$(cat ${previousConfig} | jq ". | .spec.serverPod.env[$index] | .value")
    index=$((index+1))

    if [[ "${envItemName}" == "JAVA_OPTIONS" ]];then
      envItemValue="\"${constDefaultJavaOptions} ${javaOptions}\""
    fi

    # do not copy value from SSL_ env
    if [[ "${envItemName}" == "SSL_IDENTITY_PRIVATE_KEY_ALIAS" ]] \
      || [[ "${envItemName}" == "SSL_IDENTITY_PRIVATE_KEY_PSW" ]] \
      || [[ "${envItemName}" == "SSL_IDENTITY_PRIVATE_KEYSTORE_PATH" ]] \
      || [[ "${envItemName}" == "SSL_IDENTITY_PRIVATE_KEYSTORE_TYPE" ]] \
      || [[ "${envItemName}" == "SSL_IDENTITY_PRIVATE_KEYSTORE_PSW" ]] \
      || [[ "${envItemName}" == "SSL_TRUST_KEYSTORE_PATH" ]] \
      || [[ "${envItemName}" == "SSL_TRUST_KEYSTORE_TYPE" ]] \
      || [[ "${envItemName}" == "SSL_TRUST_KEYSTORE_PSW" ]] \
      || [[ "${envItemName}" == "T3_TUNNELING_ADMIN_PORT" ]] \
      || [[ "${envItemName}" == "T3_TUNNELING_ADMIN_ADDRESS" ]] \
      || [[ "${envItemName}" == "T3_TUNNELING_CLUSTER_PORT" ]] \
      || [[ "${envItemName}" == "T3_TUNNELING_CLUSTER_ADDRESS" ]];then
      continue
    fi

    cat <<EOF >>$filePath
    - name: "${envItemName}"
      value: ${envItemValue}
EOF
done

if [[ "${ENABLE_PV,,}" == "true" ]]; then
  cat <<EOF >>$filePath
    # Optional volumes and mounts for the domain's pods. See also 'logHome'.
    volumes:
    - name: ${WLS_DOMAIN_UID}-pv-azurefile
      persistentVolumeClaim:
        claimName: ${WLS_DOMAIN_UID}-pvc-azurefile
    volumeMounts:
    - mountPath: /shared
      name: ${WLS_DOMAIN_UID}-pv-azurefile
EOF
fi

cat <<EOF >>$filePath
  # The desired behavior for starting the domain's administration server.
  adminServer:
    # Setup a Kubernetes node port for the administration server default channel
    #adminService:
    #  channels:
    #  - channelName: default
    #    nodePort: 30701
   
  # The number of admin servers to start for unlisted clusters
  replicas: 1

  # The name of each Cluster resource
  clusters:
  - name: ${WLS_DOMAIN_UID}-cluster-1

  # Change the restartVersion to force the introspector job to rerun
  # and apply any new model configuration, to also force a subsequent
  # roll of your domain's WebLogic Server pods.
  restartVersion: '${restartVersion}'

  configuration:

    # Settings for domainHomeSourceType 'FromModel'
    model:
      # Valid model domain types are 'WLS', 'JRF', and 'RestrictedJRF', default is 'WLS'
      domainType: "WLS"
      # All 'FromModel' domains require a runtimeEncryptionSecret with a 'password' field
      runtimeEncryptionSecret: "${WLS_DOMAIN_UID}-runtime-encryption-secret"
EOF

echo "set configmap..."
if [[ "${configMap}" != "null" ]];then
  cat <<EOF >>$filePath
      # Optional configmap for additional models and variable files
      configMap: ${configMap}
EOF
fi

echo "set secrets"
if [[ "${secretList}" != "null" ]];then
  secretLength=$(cat ${previousConfig} | jq '. | .spec.configuration.secrets | length')
  cat <<EOF >>$filePath
    secrets:
EOF
  index=0
  while [ $index -lt ${secretLength} ]; do
    secretItemValue=$(cat ${previousConfig} | jq ". | .spec.configuration.secrets[$index]")
    cat <<EOF >>$filePath
    - ${secretItemValue}
EOF
  index=$((index+1))
  done
fi

cat <<EOF >>$filePath

---

apiVersion: "weblogic.oracle/v1"
kind: Cluster
metadata:
  name: ${WLS_DOMAIN_UID}-cluster-1
  # Update this with the namespace your domain will run in:
  namespace: ${WLS_DOMAIN_UID}-ns
  labels:
    # Update this with the domainUID of your domain:
    weblogic.domainUID: ${WLS_DOMAIN_UID}
spec:
  # This must match a cluster name that is  specified in the WebLogic configuration
  clusterName: cluster-1
  # The number of managed servers to start for this cluster
  replicas: 2

EOF