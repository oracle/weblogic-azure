#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Function to output message to StdErr
function echo_stderr() {
    echo "$@" >&2
}

#Function to display usage message
function usage() {
    echo_stderr "./setupCoherence.sh <<< \"<coherenceConfigArgumentsFromStdIn>\""
}

function installUtilities() {
    echo "Installing zip unzip wget vnc-server rng-tools cifs-utils"
    sudo yum install -y zip unzip wget vnc-server rng-tools cifs-utils

    #Setting up rngd utils
    attempt=1
    while [[ $attempt -lt 4 ]]; do
        echo "Starting rngd service attempt $attempt"
        sudo systemctl start rngd
        attempt=$(expr $attempt + 1)
        sudo systemctl status rngd | grep running
        if [[ $? == 0 ]]; then
            echo "rngd utility service started successfully"
            break
        fi
        sleep 1m
    done
}

function validateInput() {
    if [ -z "$wlsDomainName" ]; then
        echo_stderr "wlsDomainName is required. "
    fi

    if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]; then
        echo_stderr "wlsUserName or wlsPassword is required. "
        exit 1
    fi

    if [ -z "$wlsServerName" ]; then
        echo_stderr "wlsServerName is required. "
    fi

    if [ -z "$adminVMName" ]; then
        echo_stderr "adminVMName is required. "
    fi

    if [ -z "$oracleHome" ]; then
        echo_stderr "oracleHome is required. "
    fi

    if [ -z "$wlsDomainPath" ]; then
        echo_stderr "wlsDomainPath is required. "
    fi

    if [ -z "$storageAccountName" ]; then
        echo_stderr "storageAccountName is required. "
    fi

    if [ -z "$storageAccountKey" ]; then
        echo_stderr "storageAccountKey is required. "
    fi

    if [ -z "$mountpointPath" ]; then
        echo_stderr "mountpointPath is required. "
    fi

    if [ -z "$enableWebLocalStorage" ]; then
        echo_stderr "enableWebLocalStorage is required. "
    fi

    if [ -z "$enableELK" ]; then
        echo_stderr "enableELK is required. "
    fi

    if [ -z "$elasticURI" ]; then
        echo_stderr "elasticURI is required. "
    fi

    if [ -z "$elasticUserName" ]; then
        echo_stderr "elasticUserName is required. "
    fi

    if [ -z "$elasticPassword" ]; then
        echo_stderr "elasticPassword is required. "
    fi

    if [ -z "$logsToIntegrate" ]; then
        echo_stderr "logsToIntegrate is required. "
    fi

    if [ -z "$logIndex" ]; then
        echo_stderr "logIndex is required. "
    fi

    if [ -z "$serverIndex" ]; then
        echo_stderr "serverIndex is required. "
    fi

    if [ -z "$managedServerPrefix" ]; then
        echo_stderr "managedServerPrefix is required. "
    fi

    if [ "${isCustomSSLEnabled}" != "true" ];
    then
        echo_stderr "Custom SSL value is not provided. Defaulting to false"
        isCustomSSLEnabled="false"
    else
        if   [ -z "$customIdentityKeyStoreData" ]    || [ -z "$customIdentityKeyStorePassPhrase" ] ||
             [ -z "$customIdentityKeyStoreType" ]    || [ -z "$customTrustKeyStoreData" ] ||
             [ -z "$customTrustKeyStorePassPhrase" ] || [ -z "$customTrustKeyStoreType" ] ||
             [ -z "$serverPrivateKeyAlias" ]         || [ -z "$serverPrivateKeyPassPhrase" ];
        then
            echo "One of the required values for enabling Custom SSL \
            (CustomKeyIdentityKeyStoreData,CustomKeyIdentityKeyStorePassPhrase,CustomKeyIdentityKeyStoreType,CustomKeyTrustKeyStoreData,CustomKeyTrustKeyStorePassPhrase,CustomKeyTrustKeyStoreType) \
            has not been provided."
            exit 1
        fi
    fi
}


# This function verifies whether certificate is valid and not expired
function verifyCertValidity()
{
    KEYSTORE=$1
    PASSWORD=$2
    CURRENT_DATE=$3
    MIN_CERT_VALIDITY=$4
    KEY_STORE_TYPE=$5
    VALIDITY=$(($CURRENT_DATE + ($MIN_CERT_VALIDITY*24*60*60)))
    
    echo "Verifying $KEYSTORE is valid at least $MIN_CERT_VALIDITY day from the deployment time"
    
    if [ $VALIDITY -le $CURRENT_DATE ];
    then
        echo "Error : Invalid minimum validity days supplied"
  		exit 1
  	fi 

	# Check whether KEYSTORE supplied can be opened for reading
	# Redirecting as no need to display the contents
	runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE > /dev/null 2>&1"
	if [ $? != 0 ];
	then
		echo "Error opening the keystore : $KEYSTORE"
		exit 1
	fi

	aliasList=`runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE | grep Alias" |awk '{print $3}'`
	if [[ -z $aliasList ]]; 
	then 
		echo "Error : No alias found in supplied certificate"
		exit 1
	fi
	
	for alias in $aliasList 
	do
		VALIDITY_PERIOD=`runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE -alias $alias | grep Valid"`
		echo "$KEYSTORE is \"$VALIDITY_PERIOD\""
		CERT_UNTIL_DATE=`echo $VALIDITY_PERIOD | awk -F'until:|\r' '{print $2}'`
		CERT_UNTIL_SECONDS=`date -d "$CERT_UNTIL_DATE" +%s`
		VALIDITY_REMIANS_SECONDS=`expr $CERT_UNTIL_SECONDS - $VALIDITY`
		if [[ $VALIDITY_REMIANS_SECONDS -le 0 ]];
		then
			echo "Error : Supplied certificate is either expired or expiring soon within $MIN_CERT_VALIDITY day"
			exit 1
		fi		
	done
	echo "$KEYSTORE validation is successful"
}

#run on admin server
#create coherence cluster
#associate cluster1 with the coherence cluster
#create configured cluter storage1 and enable local storage
#associate storage1 with the coherence cluster
function createCoherenceClusterModel() {
    cat <<EOF >$wlsDomainPath/configure-coherence-cluster.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
shutdown('$clientClusterName', 'Cluster')
try:
    edit()
    startEdit(60000,60000,'true')
    cd('/')
    cmo.createCoherenceClusterSystemResource('${coherenceClusterName}')
    Thread.sleep(100)

    cd('/CoherenceClusterSystemResources/${coherenceClusterName}/CoherenceClusterResource/${coherenceClusterName}/CoherenceClusterParams/${coherenceClusterName}')
    cmo.setClusteringMode('unicast')
    cmo.setClusterListenPort(${coherenceListenPort})

    cd('/')
    cmo.createCluster('${storageClusterName}')
    Thread.sleep(100)

    cd('/Clusters/${storageClusterName}')
    cmo.setClusterMessagingMode('unicast')
    cmo.setCoherenceClusterSystemResource(getMBean('/CoherenceClusterSystemResources/${coherenceClusterName}'))

    cd('/Clusters/${clientClusterName}')
    cmo.setCoherenceClusterSystemResource(getMBean('/CoherenceClusterSystemResources/${coherenceClusterName}'))

    cd('/CoherenceClusterSystemResources/${coherenceClusterName}')
    cmo.addTarget(getMBean('/Clusters/${storageClusterName}'))
    cmo.addTarget(getMBean('/Clusters/${clientClusterName}'))

    cd('/Clusters/${storageClusterName}/CoherenceTier/${storageClusterName}')
    cmo.setCoherenceWebLocalStorageEnabled(${enableWebLocalStorage})
    cmo.setLocalStorageEnabled(true)

    cd('/Clusters/${clientClusterName}/CoherenceTier/${clientClusterName}')
    cmo.setLocalStorageEnabled(false)

    cd('/ServerTemplates/${wlsServerTemplate}//ServerStart/${wlsServerTemplate}')
    arguments = cmo.getArguments()
    if(str(arguments) == 'None'):
        arguments = '${wlsCoherenceUnicastPortRange}'
    else:
        arguments = str(arguments) + ' ' + '${wlsCoherenceUnicastPortRange}'
    cmo.setArguments(arguments)

    save()
    activate()
except Exception, e :
    print e
    dumpStack()
    stopEdit('y')
    sys.exit(1)

try: 
    start('$clientClusterName', 'Cluster')
except:
    dumpStack()

disconnect()
sys.exit(0)
EOF

    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $wlsDomainPath/configure-coherence-cluster.py"
    if [[ $? != 0 ]]; then
        echo "Error : Create coherence cluster ${coherenceClusterName} failed"
        exit 1
    fi
}

#Creates weblogic deployment model for cluster domain managed server
function create_managed_model() {
    echo "Creating admin domain model"
    cat <<EOF >$wlsDomainPath/managed-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   Machine:
     '$nmHost':
         NodeManager:
             ListenAddress: "$nmHost"
             ListenPort: $nmPort
             NMType : ssl  
   Cluster:
        '$storageClusterName':
            MigrationBasis: 'database'
   Server:
        '$wlsServerName' :
           ListenPort: $storageListenPort
           Notes: "$wlsServerName managed server"
           Cluster: "$storageClusterName"
           Machine: "$nmHost"
           ServerStart:
               Arguments: '${SERVER_STARTUP_ARGS}'
EOF

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$wlsDomainPath/managed-domain.yaml
           KeyStores: 'CustomIdentityAndCustomTrust'
           CustomIdentityKeyStoreFileName: "$customIdentityKeyStoreFileName"
           CustomIdentityKeyStoreType: "$customIdentityKeyStoreType"
           CustomIdentityKeyStorePassPhraseEncrypted: "$customIdentityKeyStorePassPhrase"
           CustomTrustKeyStoreFileName: "$customTrustKeyStoreFileName"
           CustomTrustKeyStoreType: "$customTrustKeyStoreType"
           CustomTrustKeyStorePassPhraseEncrypted: "$customTrustKeyStorePassPhrase"
EOF
        fi

cat <<EOF>>$wlsDomainPath/managed-domain.yaml
           SSL:
                HostnameVerificationIgnored: true
                HostnameVerifier: 'None'
EOF

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$wlsDomainPath/managed-domain.yaml
                ServerPrivateKeyAlias: "$serverPrivateKeyAlias"
                ServerPrivateKeyPassPhraseEncrypted: "$serverPrivateKeyPassPhrase"
EOF
        fi

cat <<EOF >>$wlsDomainPath/managed-domain.yaml
   SecurityConfiguration:
       NodeManagerUsername: "$wlsUserName"
       NodeManagerPasswordEncrypted: "$wlsPassword" 
EOF

}

#This function to add machine for a given managed server
function create_machine_model() {
    echo "Creating machine name model for managed server $wlsServerName"
    cat <<EOF >$wlsDomainPath/add-machine.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
edit("$wlsServerName")
startEdit(60000,60000,'true')
cd('/')
cmo.createMachine('$nmHost')
Thread.sleep(100)
cd('/Machines/$nmHost/NodeManager/$nmHost')
cmo.setListenPort(int($nmPort))
cmo.setListenAddress('$nmHost')
cmo.setNMType('ssl')
save()
resolve()
activate()
destroyEditSession("$wlsServerName")
disconnect()
EOF
}

#This function to add managed serverto admin node
function create_ms_server_model() {
    echo "Creating managed server $wlsServerName model"
    cat <<EOF >$wlsDomainPath/add-server.py

isCustomSSLEnabled='${isCustomSSLEnabled}'
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
edit("$wlsServerName")
startEdit(60000,60000,'true')
cd('/')
cmo.createServer('$wlsServerName')
Thread.sleep(100)
cd('/Servers/$wlsServerName')
cmo.setMachine(getMBean('/Machines/$nmHost'))
cmo.setCluster(getMBean('/Clusters/$storageClusterName'))
cmo.setListenAddress('$nmHost')
cmo.setListenPort(int($storageListenPort))
cmo.setListenPortEnabled(true)

if isCustomSSLEnabled == 'true' :
    cmo.setKeyStores('CustomIdentityAndCustomTrust')
    cmo.setCustomIdentityKeyStoreFileName('$customIdentityKeyStoreFileName')
    cmo.setCustomIdentityKeyStoreType('$customIdentityKeyStoreType')
    set('CustomIdentityKeyStorePassPhrase', '$customIdentityKeyStorePassPhrase')
    cmo.setCustomTrustKeyStoreFileName('$customTrustKeyStoreFileName')
    cmo.setCustomTrustKeyStoreType('$customTrustKeyStoreType')
    set('CustomTrustKeyStorePassPhrase', '$customTrustKeyStorePassPhrase')

cd('/Servers/$wlsServerName/SSL/$wlsServerName')
cmo.setServerPrivateKeyAlias('$serverPrivateKeyAlias')
set('ServerPrivateKeyPassPhrase', '$serverPrivateKeyPassPhrase')
cmo.setHostnameVerificationIgnored(true)

cd('/Servers/$wlsServerName//ServerStart/$wlsServerName')
arguments = '${SERVER_STARTUP_ARGS} -Dweblogic.Name=$wlsServerName -Dweblogic.management.server=http://$wlsAdminURL ${wlsCoherenceUnicastPortRange}'
oldArgs = cmo.getArguments()
if oldArgs != None:
  newArgs = oldArgs + ' ' + arguments
else:
  newArgs = arguments
cmo.setArguments(newArgs)
save()
resolve()
activate()
destroyEditSession("$wlsServerName")
nmEnroll('$wlsDomainPath/$wlsDomainName','$wlsDomainPath/$wlsDomainName/nodemanager')
nmGenBootStartupProps('$wlsServerName')
disconnect()
EOF
}

#This function to check admin server status
function wait_for_admin() {
    #check admin server status
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
    echo "Check admin server status"
    while [[ "$status" != "200" ]]; do
        echo "."
        count=$((count + 1))
        if [ $count -le 30 ]; then
            sleep 1m
        else
            echo "Error : Maximum attempts exceeded while checking admin server status"
            exit 1
        fi
        status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
        if [ "$status" == "200" ]; then
            echo "WebLogic Server is running..."
            break
        fi
    done
}

# Create systemctl service for nodemanager
function createNodeManagerService() {
    echo "Setting CrashRecoveryEnabled true at $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties"
    sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g' $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    if [ $? != 0 ]; then
        echo "Warning : Failed in setting option CrashRecoveryEnabled=true. Continuing without the option."
        mv $wlsDomainPath/nodemanager/nodemanager.properties.bak $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    fi

    if [ "${isCustomSSLEnabled}" == "true" ];
    then
        echo "KeyStores=CustomIdentityAndCustomTrust" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomIdentityKeystoreType=${customIdentityKeyStoreType}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomIdentityKeyStoreFileName=${customIdentityKeyStoreFileName}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomIdentityKeyStorePassPhrase=${customIdentityKeyStorePassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomIdentityAlias=${serverPrivateKeyAlias}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomIdentityPrivateKeyPassPhrase=${serverPrivateKeyPassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomTrustKeystoreType=${customTrustKeyStoreType}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomTrustKeyStoreFileName=${customTrustKeyStoreFileName}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
        echo "CustomTrustKeyStorePassPhrase=${customTrustKeyStorePassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    fi

    sudo chown -R $username:$groupname $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties*
    echo "Creating NodeManager service"
    # Added waiting for network-online service and restart service
    cat <<EOF >/etc/systemd/system/wls_nodemanager.service
[Unit]
Description=WebLogic nodemanager service
After=network-online.target
Wants=network-online.target
 
[Service]
Type=simple
# Note that the following three parameters should be changed to the correct paths
# on your own system
WorkingDirectory=$wlsDomainPath/$wlsDomainName
Environment="JAVA_OPTIONS=${SERVER_STARTUP_ARGS}"
ExecStart="$wlsDomainPath/$wlsDomainName/bin/startNodeManager.sh"
ExecStop="$wlsDomainPath/$wlsDomainName/bin/stopNodeManager.sh"
User=oracle
Group=oracle
KillMode=process
LimitNOFILE=65535
Restart=always
RestartSec=3
 
[Install]
WantedBy=multi-user.target
EOF
}

#This function to start managed server
function startManagedServer() {
    echo "Starting managed server $wlsServerName"
    cat <<EOF >$wlsDomainPath/start-server.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
   start('$wlsServerName', 'Server')
except:
   print "Failed starting managed server $wlsServerName"
   dumpStack()
disconnect()
EOF
    sudo chown -R $username:$groupname $wlsDomainPath
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $wlsDomainPath/start-server.py"
    if [[ $? != 0 ]]; then
        echo "Error : Failed in starting managed server $wlsServerName"
        exit 1
    fi
}

# Create managed server setup
function createManagedSetup() {
    echo "Creating Managed Server Setup"
    cd $wlsDomainPath
    
    # WebLogic base images are already having weblogic-deploy, hence no need to download
    if [ ! -d "$wlsDomainPath/weblogic-deploy" ];
    then
        echo "weblogic-deploy tool not found in path $wlsDomainPath"
        exit 1
    fi
    
    echo "Creating managed server model files"
    create_managed_model
    create_machine_model
    create_ms_server_model
    echo "Completed managed server model files"
    sudo chown -R $username:$groupname $wlsDomainPath
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $wlsDomainPath/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $wlsDomainPath  -domain_type WLS -model_file $wlsDomainPath/managed-domain.yaml"
    if [[ $? != 0 ]]; then
        echo "Error : Managed setup failed"
        exit 1
    fi
    wait_for_admin

    # For issue https://github.com/wls-eng/arm-oraclelinux-wls/issues/89
    getSerializedSystemIniFileFromShare

    echo "Adding machine to managed server $wlsServerName"
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $wlsDomainPath/add-machine.py"
    if [[ $? != 0 ]]; then
        echo "Error : Adding machine for managed server $wlsServerName failed"
        exit 1
    fi
    echo "Adding managed server $wlsServerName"
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $wlsDomainPath/add-server.py"
    if [[ $? != 0 ]]; then
        echo "Error : Adding server $wlsServerName failed"
        exit 1
    fi
}

function enabledAndStartNodeManagerService() {
    sudo systemctl enable wls_nodemanager
    sudo systemctl daemon-reload
    attempt=1
    while [[ $attempt -lt 6 ]]; do
        echo "Starting nodemanager service attempt $attempt"
        sudo systemctl start wls_nodemanager
        attempt=$(expr $attempt + 1)
        sudo systemctl status wls_nodemanager | grep running
        if [[ $? == 0 ]]; then
            echo "wls_nodemanager service started successfully"
            break
        fi
        sleep 3m
    done
}

function cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf $wlsDomainPath/managed-domain.yaml
    rm -rf $wlsDomainPath/*.py
    rm -rf ${CUSTOM_HOSTNAME_VERIFIER_HOME}
    echo "Cleanup completed."
}

function openPortsForCoherence() {
    # for Oracle Linux 7.3, 7.4, iptable is not running.
    if [ -z $(command -v firewall-cmd) ]; then
        return 0
    fi

    # for Oracle Linux 7.6, open weblogic ports
    echo "update network rules for managed server"
    sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/tcp
    sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/udp
    sudo firewall-cmd --zone=public --add-port=$storageListenPort/tcp

    sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/tcp
    sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/udp
    # Coherence TcpRing/IpMonitor  port 7
    sudo firewall-cmd --zone=public --add-port=7/tcp
    sudo firewall-cmd --zone=public --add-port=$nmPort/tcp

    sudo firewall-cmd --runtime-to-permanent
    sudo systemctl restart firewalld
}

# Mount the Azure file share on all VMs created
function mountFileShare() {
    echo "Creating mount point"
    echo "Mount point: $mountpointPath"
    sudo mkdir -p $mountpointPath
    if [ ! -d "/etc/smbcredentials" ]; then
        sudo mkdir /etc/smbcredentials
    fi
    if [ ! -f "/etc/smbcredentials/${storageAccountName}.cred" ]; then
        echo "Crearing smbcredentials"
        echo "username=$storageAccountName >> /etc/smbcredentials/${storageAccountName}.cred"
        echo "password=$storageAccountKey >> /etc/smbcredentials/${storageAccountName}.cred"
        sudo bash -c "echo "username=$storageAccountName" >> /etc/smbcredentials/${storageAccountName}.cred"
        sudo bash -c "echo "password=$storageAccountKey" >> /etc/smbcredentials/${storageAccountName}.cred"
    fi
    echo "chmod 600 /etc/smbcredentials/${storageAccountName}.cred"
    sudo chmod 600 /etc/smbcredentials/${storageAccountName}.cred
    echo "//${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino"
    sudo bash -c "echo \"//${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino\" >> /etc/fstab"
    echo "mount -t cifs //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino"
    sudo mount -t cifs //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
    if [[ $? != 0 ]]; then
        echo "Failed to mount //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath"
        exit 1
    fi
}

# Get SerializedSystemIni.dat file from share point to managed server vm
function getSerializedSystemIniFileFromShare() {
    runuser -l oracle -c "mv ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat.backup"
    runuser -l oracle -c "cp ${mountpointPath}/SerializedSystemIni.dat ${wlsDomainPath}/${wlsDomainName}/security/."
    ls -lt ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat
    if [[ $? != 0 ]]; then
        echo "Failed to get ${mountpointPath}/SerializedSystemIni.dat"
        exit 1
    fi
    runuser -l oracle -c "chmod 640 ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat"
}

function validateSSLKeyStores()
{
   sudo chown -R $username:$groupname $KEYSTORE_PATH

   #validate identity keystore
   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customIdentityKeyStoreFileName -storepass $customIdentityKeyStorePassPhrase -storetype $customIdentityKeyStoreType | grep 'Entry type:' | grep 'PrivateKeyEntry'"

   if [[ $? != 0 ]]; then
       echo "Error : Identity Keystore Validation Failed !!"
       exit 1
   fi
   
   # Verify Identity keystore validity period more than MIN_CERT_VALIDITY
   verifyCertValidity $customIdentityKeyStoreFileName $customIdentityKeyStorePassPhrase $CURRENT_DATE $MIN_CERT_VALIDITY $customIdentityKeyStoreType

   #validate Trust keystore
   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customTrustKeyStoreFileName -storepass $customTrustKeyStorePassPhrase -storetype $customTrustKeyStoreType | grep 'Entry type:' | grep 'trustedCertEntry'"

   if [[ $? != 0 ]]; then
       echo "Error : Trust Keystore Validation Failed !!"
       exit 1
   fi

   # Verify Identity keystore validity period more than MIN_CERT_VALIDITY
   verifyCertValidity $customTrustKeyStoreFileName $customTrustKeyStorePassPhrase $CURRENT_DATE $MIN_CERT_VALIDITY $customTrustKeyStoreType

   echo "ValidateSSLKeyStores Successfull !!"
}

function storeCustomSSLCerts()
{
    if [ "${isCustomSSLEnabled}" == "true" ];
    then

        mkdir -p $KEYSTORE_PATH

        echo "Custom SSL is enabled. Storing CertInfo as files..."
        customIdentityKeyStoreFileName="$KEYSTORE_PATH/identity.keystore"
        customTrustKeyStoreFileName="$KEYSTORE_PATH/trust.keystore"

        customIdentityKeyStoreData=$(echo "$customIdentityKeyStoreData" | base64 --decode)
        customIdentityKeyStorePassPhrase=$(echo "$customIdentityKeyStorePassPhrase" | base64 --decode)

        customTrustKeyStoreData=$(echo "$customTrustKeyStoreData" | base64 --decode)
        customTrustKeyStorePassPhrase=$(echo "$customTrustKeyStorePassPhrase" | base64 --decode)

        serverPrivateKeyAlias=$(echo "$serverPrivateKeyAlias" | base64 --decode)
        serverPrivateKeyPassPhrase=$(echo "$serverPrivateKeyPassPhrase" | base64 --decode)

        #decode cert data once again as it would got base64 encoded while  storing in azure keyvault
        echo "$customIdentityKeyStoreData" | base64 --decode > $customIdentityKeyStoreFileName
        echo "$customTrustKeyStoreData" | base64 --decode > $customTrustKeyStoreFileName

        validateSSLKeyStores

    else
        echo "Custom SSL is not enabled"
    fi
}

function generateCustomHostNameVerifier()
{
   mkdir -p ${CUSTOM_HOSTNAME_VERIFIER_HOME}
   mkdir -p ${CUSTOM_HOSTNAME_VERIFIER_HOME}/src/main/java
   mkdir -p ${CUSTOM_HOSTNAME_VERIFIER_HOME}/src/test/java
   cp ${BASE_DIR}/generateCustomHostNameVerifier.sh ${CUSTOM_HOSTNAME_VERIFIER_HOME}/generateCustomHostNameVerifier.sh
   cp ${BASE_DIR}/WebLogicCustomHostNameVerifier.java ${CUSTOM_HOSTNAME_VERIFIER_HOME}/src/main/java/WebLogicCustomHostNameVerifier.java
   cp ${BASE_DIR}/HostNameValuesTemplate.txt ${CUSTOM_HOSTNAME_VERIFIER_HOME}/src/main/java/HostNameValuesTemplate.txt
   cp ${BASE_DIR}/WebLogicCustomHostNameVerifierTest.java ${CUSTOM_HOSTNAME_VERIFIER_HOME}/src/test/java/WebLogicCustomHostNameVerifierTest.java
   chown -R $username:$groupname ${CUSTOM_HOSTNAME_VERIFIER_HOME}
   chmod +x ${CUSTOM_HOSTNAME_VERIFIER_HOME}/generateCustomHostNameVerifier.sh

   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; ${CUSTOM_HOSTNAME_VERIFIER_HOME}/generateCustomHostNameVerifier.sh ${adminVMName} ${customDNSNameForAdminServer} ${customDNSNameForAdminServer} ${dnsLabelPrefix} ${wlsDomainName} ${location}"
}

function copyCustomHostNameVerifierJarsToWebLogicClasspath()
{
   runuser -l oracle -c "cp ${CUSTOM_HOSTNAME_VERIFIER_HOME}/output/*.jar $oracleHome/wlserver/server/lib/;"

   echo "Modify WLS CLASSPATH to include hostname verifier jars...."
   sed -i 's;^WEBLOGIC_CLASSPATH="${WL_HOME}/server/lib/postgresql.*;&\nWEBLOGIC_CLASSPATH="${WL_HOME}/server/lib/hostnamevalues.jar:${WL_HOME}/server/lib/weblogicustomhostnameverifier.jar:${WEBLOGIC_CLASSPATH}";' $oracleHome/oracle_common/common/bin/commExtEnv.sh
   echo "Modified WLS CLASSPATH to include hostname verifier jars."
}


function configureCustomHostNameVerifier()
{
    echo "configureCustomHostNameVerifier for domain  $wlsDomainName for server $wlsServerName"
    cat <<EOF >$DOMAIN_PATH/configureCustomHostNameVerifier.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
    edit("$wlsServerName")
    startEdit()

    cd('/Servers/$wlsServerName/SSL/$wlsServerName')
    cmo.setHostnameVerifier('com.oracle.azure.weblogic.security.util.WebLogicCustomHostNameVerifier')
    cmo.setHostnameVerificationIgnored(false)
    cmo.setTwoWaySSLEnabled(false)
    cmo.setClientCertificateEnforced(false)

    save()
    activate()
except Exception,e:
    print e
    print "Failed to configureCustomHostNameVerifier for domain  $wlsDomainName"
    dumpStack()
    raise Exception('Failed to configureCustomHostNameVerifier for domain  $wlsDomainName')
disconnect()
EOF
sudo chown -R $username:$groupname $DOMAIN_PATH
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/configureCustomHostNameVerifier.py"
if [[ $? != 0 ]]; then
  echo "Error : Failed to configureCustomHostNameVerifier for domain $wlsDomainName"
  exit 1
fi

}

# main script starts from here

SCRIPT_PWD=$(pwd)
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

# Used for certificate expiry validation
CURRENT_DATE=`date +%s`
# Supplied certificate to have minimum days validity for the deployment
MIN_CERT_VALIDITY="1"


# store arguments in a special array
#args=("$@")
# get number of elements
#ELEMENTS=${#args[@]}

# echo each element in array
# for loop
#for ((i = 0; i < $ELEMENTS; i++)); do
#    echo "ARG[${args[${i}]}]"
#done

read wlsDomainName wlsUserName wlsPassword adminVMName oracleHome wlsDomainPath storageAccountName storageAccountKey mountpointPath enableWebLocalStorage enableELK elasticURI elasticUserName elasticPassword logsToIntegrate logIndex managedServerPrefix serverIndex customDNSNameForAdminServer dnsLabelPrefix location isCustomSSLEnabled customIdentityKeyStoreData customIdentityKeyStorePassPhrase customIdentityKeyStoreType customTrustKeyStoreData customTrustKeyStorePassPhrase customTrustKeyStoreType serverPrivateKeyAlias serverPrivateKeyPassPhrase

isCustomSSLEnabled="${isCustomSSLEnabled,,}"

clientClusterName="cluster1"
coherenceClusterName="myCoherence"
coherenceListenPort=7574
coherenceLocalport=42000
coherenceLocalportAdjust=42200
groupname="oracle"
nmHost=$(hostname)
nmPort=5556
storageClusterName="storage1"
storageListenPort=7501
username="oracle"
wlsAdminT3ChannelPort=7005
wlsAdminURL="${adminVMName}:${wlsAdminT3ChannelPort}"
wlsCoherenceUnicastPortRange="-Dcoherence.localport=$coherenceLocalport -Dcoherence.localport.adjust=$coherenceLocalportAdjust"
wlsServerTemplate="myServerTemplate"
KEYSTORE_PATH="${wlsDomainPath}/${wlsDomainName}/keystores"
SERVER_STARTUP_ARGS="-Dlog4j2.formatMsgNoLookups=true"
CUSTOM_HOSTNAME_VERIFIER_HOME="/u01/app/custom-hostname-verifier"

if [ ${serverIndex} -eq 0 ]; then
    wlsServerName="admin"
else
    wlsServerName="${managedServerPrefix}${serverIndex}"
fi

validateInput
cleanup

# Executing this function first just to make sure certificate errors are first caught
storeCustomSSLCerts

if [ $wlsServerName == "admin" ]; then
    createCoherenceClusterModel
    cleanup
else
    installUtilities
    mountFileShare
    openPortsForCoherence
    createManagedSetup
    generateCustomHostNameVerifier
    copyCustomHostNameVerifierJarsToWebLogicClasspath
    createNodeManagerService
    enabledAndStartNodeManagerService
    configureCustomHostNameVerifier
    startManagedServer
    cleanup

    echo "enable ELK? ${enableELK}"
    chmod ugo+x ${SCRIPT_PWD}/elkIntegrationForConfiguredCluster.sh
    if [[ "${enableELK,,}" == "true" ]]; then
        echo "Set up ELK..."
        ${SCRIPT_PWD}/elkIntegrationForConfiguredCluster.sh \
            ${oracleHome} \
            ${wlsAdminURL} \
            ${wlsUserName} \
            ${wlsPassword} \
            "admin" \
            ${elasticURI} \
            ${elasticUserName} \
            ${elasticPassword} \
            ${wlsDomainName} \
            ${wlsDomainPath}/${wlsDomainName} \
            ${logsToIntegrate} \
            ${serverIndex} \
            ${logIndex} \
            ${managedServerPrefix}
    fi
fi
