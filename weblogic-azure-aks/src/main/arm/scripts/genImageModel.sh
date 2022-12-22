# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Initialize
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh

export filePath=$1
export appPackageUrls=$2
export enableCustomSSL=$3
export enableAdminT3Tunneling=$4
export enableClusterT3Tunneling=$5

export enableT3s=${enableCustomSSL,,}
export t3Protocol="t3"
export t3ChannelName="T3Channel"

if [ "${enableCustomSSL,,}" == "true" ]; then
  t3Protocol="t3s"
  t3ChannelName="T3sChannel"
fi

cat <<EOF >${filePath}
# Copyright (c) 2020, 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Based on ./kubernetes/samples/scripts/create-weblogic-domain/model-in-image/model-images/model-in-image__WLS-v1/model.10.yaml
# in https://github.com/oracle/weblogic-kubernetes-operator.

domainInfo:
  AdminUserName: "@@SECRET:__weblogic-credentials__:username@@"
  AdminPassword: "@@SECRET:__weblogic-credentials__:password@@"
  ServerStartMode: "prod"

topology:
  Name: "@@ENV:CUSTOM_DOMAIN_NAME@@"
  ProductionModeEnabled: true
  AdminServerName: "admin-server"
  Cluster:
    "cluster-1":
      DynamicServers:
        ServerTemplate: "cluster-1-template"
        ServerNamePrefix: "@@ENV:MANAGED_SERVER_PREFIX@@"
        DynamicClusterSize: "@@PROP:CLUSTER_SIZE@@"
        MaxDynamicClusterSize: "@@PROP:CLUSTER_SIZE@@"
        MinDynamicClusterSize: "0"
        CalculatedListenPorts: false
  Server:
    "admin-server":
      ListenPort: 7001
EOF

if [[ "${enableAdminT3Tunneling,,}" == "true" ]];then
  cat <<EOF >>${filePath}
      NetworkAccessPoint:
        ${t3ChannelName}:
          Protocol: '${t3Protocol}'
          ListenPort: "@@ENV:T3_TUNNELING_ADMIN_PORT@@"
          PublicPort: "@@ENV:T3_TUNNELING_ADMIN_PORT@@"
          HttpEnabledForThisProtocol: true
          OutboundEnabled: false
          Enabled: true
          TwoWaySSLEnabled: ${enableT3s}
          ClientCertificateEnforced: false
          TunnelingEnabled: true
          PublicAddress: '@@ENV:T3_TUNNELING_ADMIN_ADDRESS@@'
EOF
fi

if [[ "${enableCustomSSL,,}" == "true" ]]; then
  cat <<EOF >>${filePath}
      SSL:
        HostnameVerificationIgnored: true
        ListenPort: 7002
        Enabled: true
        HostnameVerifier: 'None'
        ServerPrivateKeyAlias: "@@ENV:SSL_IDENTITY_PRIVATE_KEY_ALIAS@@"
        ServerPrivateKeyPassPhraseEncrypted: "@@ENV:SSL_IDENTITY_PRIVATE_KEY_PSW@@"
      KeyStores: 'CustomIdentityAndCustomTrust'
      CustomIdentityKeyStoreFileName: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_PATH@@"
      CustomIdentityKeyStoreType: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_TYPE@@"
      CustomIdentityKeyStorePassPhraseEncrypted: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_PSW@@"
      CustomTrustKeyStoreFileName: "@@ENV:SSL_TRUST_KEYSTORE_PATH@@"
      CustomTrustKeyStoreType: "@@ENV:SSL_TRUST_KEYSTORE_TYPE@@"
      CustomTrustKeyStorePassPhraseEncrypted: "@@ENV:SSL_TRUST_KEYSTORE_PSW@@"
EOF
fi

cat <<EOF >>${filePath}
  ServerTemplate:
    "cluster-1-template":
      Cluster: "cluster-1"
      ListenPort: 8001
EOF

if [[ "${enableClusterT3Tunneling,,}" == "true" ]];then
  cat <<EOF >>${filePath}
      NetworkAccessPoint:
        ${t3ChannelName}:
          Protocol: '${t3Protocol}'
          ListenPort: "@@ENV:T3_TUNNELING_CLUSTER_PORT@@"
          PublicPort: "@@ENV:T3_TUNNELING_CLUSTER_PORT@@"
          HttpEnabledForThisProtocol: true
          OutboundEnabled: false
          Enabled: true
          TwoWaySSLEnabled: ${enableT3s}
          ClientCertificateEnforced: false
          TunnelingEnabled: true
          PublicAddress: '@@ENV:T3_TUNNELING_CLUSTER_ADDRESS@@'
EOF
fi

if [[ "${enableCustomSSL,,}" == "true" ]];then
  cat <<EOF >>${filePath}
      SSL:
        HostnameVerificationIgnored: true
        ListenPort: 8002
        Enabled: true
        HostnameVerifier: 'None'
        ServerPrivateKeyAlias: "@@ENV:SSL_IDENTITY_PRIVATE_KEY_ALIAS@@"
        ServerPrivateKeyPassPhraseEncrypted: "@@ENV:SSL_IDENTITY_PRIVATE_KEY_PSW@@"
      KeyStores: 'CustomIdentityAndCustomTrust'
      CustomIdentityKeyStoreFileName: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_PATH@@"
      CustomIdentityKeyStoreType: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_TYPE@@"
      CustomIdentityKeyStorePassPhraseEncrypted: "@@ENV:SSL_IDENTITY_PRIVATE_KEYSTORE_PSW@@"
      CustomTrustKeyStoreFileName: "@@ENV:SSL_TRUST_KEYSTORE_PATH@@"
      CustomTrustKeyStoreType: "@@ENV:SSL_TRUST_KEYSTORE_TYPE@@"
      CustomTrustKeyStorePassPhraseEncrypted: "@@ENV:SSL_TRUST_KEYSTORE_PSW@@"
EOF
fi

cat <<EOF >>${filePath}
  SecurityConfiguration:
    NodeManagerUsername: "@@SECRET:__weblogic-credentials__:username@@"
    NodeManagerPasswordEncrypted: "@@SECRET:__weblogic-credentials__:password@@"
    
resources:
  SelfTuning:
    MinThreadsConstraint:
      SampleMinThreads:
        Target: "cluster-1"
        Count: 1
    MaxThreadsConstraint:
      SampleMaxThreads:
        Target: "cluster-1"
        Count: 10
    WorkManager:
      SampleWM:
        Target: "cluster-1"
        MinThreadsConstraint: "SampleMinThreads"
        MaxThreadsConstraint: "SampleMaxThreads"

EOF

if [ "${appPackageUrls}" == "[]" ]; then
        exit 0
fi

    cat <<EOF >>${filePath}
appDeployments:
  Application:
EOF
    appPackageUrls=$(echo "${appPackageUrls:1:${#appPackageUrls}-2}")
    appUrlArray=$(echo $appPackageUrls | tr "," "\n")

    index=1
    for item in $appUrlArray; do
        echo ${item}
        item=$(echo $item | tr -d "\"") # remove ""
        # e.g. https://wlsaksapp.blob.core.windows.net/japps/testwebapp.war?sp=r&se=2021-04-29T15:12:38Z&sv=2020-02-10&sr=b&sig=7grL4qP%2BcJ%2BLfDJgHXiDeQ2ZvlWosRLRQ1ciLk0Kl7M%3D
        urlWithoutQueryString="${item%\?*}"
        echo $urlWithoutQueryString
        fileName="${urlWithoutQueryString##*/}"
        echo $fileName
        fileExtension="${fileName##*.}"
        echo ${fileExtension}
        # support .ear, .war, .jar files.
        if [[ "${fileExtension,,}" != "ear" ]] &&
          [[ "${fileExtension,,}" != "war" ]] &&
          [[ "${fileExtension,,}" != "jar" ]]; then
          continue
        fi

        curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fL "$item" -o ${scriptDir}/model-images/wlsdeploy/applications/${fileName}
        if [ $? -ne 0 ];then
          echo "Failed to download $item"
          exit 1
        fi
        cat <<EOF >>${filePath}
    app${index}:
      SourcePath: 'wlsdeploy/applications/${fileName}'
      ModuleType: ${fileExtension}
      Target: 'cluster-1'
EOF
        index=$((index + 1))
    done

# print model
cat ${filePath}