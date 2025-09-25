#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
    echo_stderr "./setupOHS.sh <<< \"<ohsSetupArgumentsFromStdIn>\""
}

# Create user "oracle", used for instalation and setup
function addOracleGroupAndUser()
{
    #add oracle group and user
    echo "Adding oracle user and group..."
    groupname="oracle"
    username="oracle"
    user_home_dir="/u01/oracle"
    USER_GROUP=${groupname}
    sudo groupadd $groupname
    sudo useradd -d ${user_home_dir} -g $groupname $username
}

# Cleaning all installer files 
function cleanup()
{
    echo "Cleaning up temporary files..."
    rm -f $BASE_DIR/setupOHS.sh
    rm -f $OHS_PATH/ohs-domain.py
    echo "Cleanup completed."
}

# Verifies whether user inputs are available
function validateInput()
{
    if [ -z "$OHS_DOMAIN_NAME" ]
    then
       echo_stderr "OHS domain name is required. "
       exit 1
    fi	
    
    if [ -z "$OHS_COMPONENT_NAME" ]
    then
       echo_stderr "OHS domain name is required. "
       exit 1
    fi	
    
    if [[ -z "$OHS_NM_USER" || -z "$OHS_NM_SHIBBOLETH" ]]
    then
       echo_stderr "OHS OHS_NM_USER and OHS_NM_SHIBBOLETH is required. "
       exit 1
    fi	
    
    if [[ -z "$OHS_HTTP_PORT" || -z "$OHS_HTTPS_PORT" ]]
    then
       echo_stderr "OHS http port and OHS https port required."
       exit 1
    fi	
    
    if [ -z "$WLS_REST_URL" ] 
    then
       echo_stderr "WebLogic REST management url is required."
       exit 1
    fi
    
    if [ -z "${OHS_KEY_STORE_DATA}" ] || [ -z "${OHS_KEY_STORE_PASSPHRASE}" ]
    then
       echo_stderr "One of the required values for enabling Custom SSL (ohsKeyStoreData,ohsKeyStorePassPhrase) is not provided"
    fi
    
    if [ -z "$ORACLE_VAULT_SHIBBOLETH" ]
    then
       echo_stderr "ORACLE_VAULT_SHIBBOLETH is required to add custom ssl to OHS server"
    fi
    
    if [ -z "${WLS_USER}" ] || [ -z "${WLS_SHIBBOLETH}" ]
    then
       echo_stderr "Either WLS_USER or WLS_SHIBBOLETH is required"
    fi
    
    if [ -z "$OHS_KEY_TYPE" ] 
    then
       echo_stderr "Provide KeyType either JKS or PKCS12"
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
    
    echo "Verifying $KEYSTORE is valid at least $MIN_CERT_VALIDITY day from the OHS deployment time"
    
    if [ $VALIDITY -le $CURRENT_DATE ];
    then
        echo_stderr "Error : Invalid minimum validity days supplied"
  		exit 1
  	fi 

	# Check whether KEYSTORE supplied can be opened for reading
	# Redirecting as no need to display the contents
	runuser -l oracle -c "$JAVA_HOME/bin/keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE > /dev/null 2>&1"
	if [ $? != 0 ];
	then
		echo_stderr "Error opening the keystore : $KEYSTORE"
		exit 1
	fi

	aliasList=`runuser -l oracle -c "$JAVA_HOME/bin/keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE | grep Alias" |awk '{print $3}'`
	if [[ -z $aliasList ]]; 
	then 
		echo_stderr "Error : No alias found in supplied certificate $KEYSTORE"
		exit 1
	fi
	
	for alias in $aliasList 
	do
		VALIDITY_PERIOD=`runuser -l oracle -c "$JAVA_HOME/bin/keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE -alias $alias | grep Valid"`
		echo "$KEYSTORE is \"$VALIDITY_PERIOD\""
		CERT_UNTIL_DATE=`echo $VALIDITY_PERIOD | awk -F'until:|\r' '{print $2}'`
		CERT_UNTIL_SECONDS=`date -d "$CERT_UNTIL_DATE" +%s`
		VALIDITY_REMIANS_SECONDS=`expr $CERT_UNTIL_SECONDS - $VALIDITY`
		if [[ $VALIDITY_REMIANS_SECONDS -le 0 ]];
		then
			echo_stderr "$KEYSTORE is \"$VALIDITY_PERIOD\""
			echo_stderr "Error : Supplied certificate $KEYSTORE is either expired or expiring soon within $MIN_CERT_VALIDITY day"
			exit 1
		fi		
	done
	echo "$KEYSTORE validation is successful"
}

# Setup Domain path
function setupDomainPath()
{
    #create custom directory for setting up wls and jdk
    sudo mkdir -p $DOMAIN_PATH
    sudo chown -R $username:$groupname $DOMAIN_PATH 
}

# Create .py file to setup OHS domain
function createDomainConfigFile()
{
    echo "creating OHS domain configuration file ..."
    cat <<EOF >$OHS_PATH/ohs-domain.py
import os, sys
setTopologyProfile('Compact')
selectTemplate('Oracle HTTP Server (Standalone)')
loadTemplates()
showTemplates()
cd('/')
create("${OHS_COMPONENT_NAME}", 'SystemComponent')
cd('SystemComponent/' + '${OHS_COMPONENT_NAME}')
set('ComponentType','OHS')
cd('/')
cd('OHS/' + '${OHS_COMPONENT_NAME}')
set('ListenAddress','')
set('ListenPort', '${OHS_HTTP_PORT}')
set('SSLListenPort', '${OHS_HTTPS_PORT}')
cd('/')
create('sc', 'SecurityConfiguration')
cd('SecurityConfiguration/sc')
set('NodeManagerUsername', "${OHS_NM_USER}")
set('NodeManagerPasswordEncrypted', "${OHS_NM_SHIBBOLETH}")
setOption('NodeManagerType','PerDomainNodeManager')
setOption('OverwriteDomain', 'true')
writeDomain("${OHS_DOMAIN_PATH}")
dumpStack()
closeTemplate()
exit()

EOF
}

#Configuring OHS standalone domain
function setupOHSDomain()
{
    createDomainConfigFile
    sudo chown -R $username:$groupname $OHS_PATH/ohs-domain.py
    echo "Setting up OHS standalone domain at ${OHS_DOMAIN_PATH}"
    runuser -l oracle -c  "${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/common/bin/wlst.sh $OHS_PATH/ohs-domain.py"
    if [[ $?==0 ]]; 
    then
        echo "OHS standalone domain is configured successfully"
    else
        echo_stderr "OHS standalone domain is configuration failed"
        exit 1
    fi	
}

# Create OHS silent installation templates
function createOHSTemplates()
{
    sudo cp $BASE_DIR/$OHS_FILE_NAME $OHS_PATH/$OHS_FILE_NAME
    echo "unzipping $OHS_FILE_NAME"
    sudo unzip -o $OHS_PATH/$OHS_FILE_NAME -d $OHS_PATH
    SILENT_FILES_DIR=$OHS_PATH/silent-template
    sudo mkdir -p $SILENT_FILES_DIR
    sudo rm -rf $OHS_PATH/silent-template/*
    mkdir -p $INSTALL_PATH
    create_oraInstlocTemplate
    create_oraResponseTemplate
    sudo chown -R $username:$groupname $OHS_PATH
    sudo chown -R $username:$groupname $INSTALL_PATH
}

# Create OHS nodemanager as service
function create_nodemanager_service()
{
    echo "Setting CrashRecoveryEnabled true at $DOMAIN_PATH/$OHS_DOMAIN_NAME/nodemanager/nodemanager.properties"
    sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g'  $DOMAIN_PATH/$OHS_DOMAIN_NAME/nodemanager/nodemanager.properties
    if [ $? != 0 ];
    then
        echo "Warning : Failed in setting option CrashRecoveryEnabled=true. Continuing without the option."
        mv $DOMAIN_PATH/nodemanager/nodemanager.properties.bak $DOMAIN_PATH/$OHS_DOMAIN_NAME/nodemanager/nodemanager.properties
    fi
    sudo chown -R $username:$groupname $DOMAIN_PATH/$OHS_DOMAIN_NAME/nodemanager/nodemanager.properties*
    echo "Creating NodeManager service"
    cat <<EOF >/etc/systemd/system/ohs_nodemanager.service
    [Unit]
    Description=OHS nodemanager service
    After=network-online.target
    Wants=network-online.target
    [Service]
    Type=simple
    WorkingDirectory=/u01/domains
    ExecStart=/bin/bash $DOMAIN_PATH/$OHS_DOMAIN_NAME/bin/startNodeManager.sh
    ExecStop=/bin/bash $DOMAIN_PATH/$OHS_DOMAIN_NAME/bin/stopNodeManager.sh
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

# Start the nodemanager service
function enabledAndStartNodeManagerService()
{
    sudo systemctl enable ohs_nodemanager
    sudo systemctl daemon-reload
    attempt=1
    while [[ $attempt -lt 6 ]]
    do
        echo "Starting nodemanager service attempt $attempt"
        sudo systemctl start ohs_nodemanager
        sleep 1m
        attempt=`expr $attempt + 1`
        sudo systemctl status ohs_nodemanager | grep "active (running)"
        if [[ $? == 0 ]];
  	then
            echo "ohs_nodemanager service started successfully"
            break
        fi
        sleep 3m
    done
}

#Create Start component script
function createStartComponent()
{
    cat <<EOF > $OHS_DOMAIN_PATH/startComponent.py 
import os, sys
nmConnect(username='${OHS_NM_USER}',password='${OHS_NM_SHIBBOLETH}',domainName='${OHS_DOMAIN_NAME}')
status=nmServerStatus(serverName='${OHS_COMPONENT_NAME}',serverType='OHS')
if status != "RUNNING":
  nmStart(serverName='${OHS_COMPONENT_NAME}',serverType='OHS')
  nmServerStatus(serverName='${OHS_COMPONENT_NAME}',serverType='OHS')
else:
  print 'OHS component ${OHS_COMPONENT_NAME} is already running'
EOF

    sudo chown -R $username:$groupname $OHS_DOMAIN_PATH/startComponent.py
}

#Create Stop component script
function createStopComponent()
{
    cat <<EOF > $OHS_DOMAIN_PATH/stopComponent.py 
import os, sys
nmConnect(username='${OHS_NM_USER}',password='${OHS_NM_SHIBBOLETH}',domainName='${OHS_DOMAIN_NAME}')
status=nmServerStatus(serverName='${OHS_COMPONENT_NAME}',serverType='OHS')
if status != "SHUTDOWN":
  nmKill(serverName='$OHS_COMPONENT_NAME',serverType='OHS')
  nmServerStatus(serverName='$OHS_COMPONENT_NAME',serverType='OHS')
else:
  print 'OHS component ${OHS_COMPONENT_NAME} is already SHUTDOWN'
EOF

    sudo chown -R $username:$groupname $OHS_DOMAIN_PATH/stopComponent.py

}

# Create OHS component as service
function createComponentService()
{
    echo "Creating ohs component service"
    cat <<EOF >/etc/systemd/system/ohs_component.service
    [Unit]
    Description=OHS Component service
    After=ohs_nodemanager.service
    Wants=ohs_nodemanager.service
	
    [Service]
    Type=oneshot
    RemainAfterExit=true
    WorkingDirectory="$DOMAIN_PATH/$OHS_DOMAIN_NAME"
    ExecStart=${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/common/bin/wlst.sh $OHS_DOMAIN_PATH/startComponent.py
    ExecStop=${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/common/bin/wlst.sh $OHS_DOMAIN_PATH/stopComponent.py
    User=oracle
    Group=oracle
    KillMode=process
    LimitNOFILE=65535
[Install]
WantedBy=multi-user.target

EOF

}

# Start the OHS component service
function enableAndStartOHSServerService()
{
    sudo systemctl enable ohs_component
    sudo systemctl daemon-reload
    echo "Starting ohs component service"
    attempt=1
    while [[ $attempt -lt 6 ]]
    do
        echo "Starting ohs component service attempt $attempt"
  	sudo systemctl start ohs_component
  	sleep 1m
  	attempt=`expr $attempt + 1`
  	sudo systemctl status ohs_component | grep active
  	if [[ $? == 0 ]];
  	then
  	    echo "ohs_component service started successfully"
  	    break
  	fi
  	sleep 3m
  done
}

# Query the WLS and form WLS cluster address
function getWLSClusterAddress()
{
    restArgs=" -v --user ${WLS_USER}:${WLS_SHIBBOLETH} -H X-Requested-By:MyClient -H Accept:application/json -H Content-Type:application/json"
    curl $restArgs -X GET ${WLS_REST_URL}/domainRuntime/serverRuntimes?fields=defaultURL > out
    if [[ $? != 0 ]];
    then
        echo_stderr "REST query failed for servers"
        exit 1
    fi
    # Default admin URL is "defaultURL": "t3:\/\/10.0.0.6:7001" which is not required as part of cluster address
    # Exclude 7001 admin port, 7005 admin channel port
    # Exclude coherence server listen port 7501
    msString=` cat out | grep defaultURL | grep -v "7001\|7005\|7501" | cut -f3 -d"/" `
    wlsClusterAddress=`echo $msString | sed 's/\" /,/g'`
    WLS_CLUSTER_ADDRESS=${wlsClusterAddress::-1}
  
    # Test whether servers are reachable
    testClusterServers=$(echo ${WLS_CLUSTER_ADDRESS} | tr "," "\n")
    for server in $testClusterServers
    do
        echo curl http://${server}/weblogic/ready
        curl http://${server}/weblogic/ready
        if [[ $? == 0 ]];
        then
            echo "${server} is reachable"
        else
            echo_stderr "Failed to get cluster address properly. Cluster address received: ${wlsClusterAddress}"
            exit 1
        fi
    done
    rm -f out
}

# Create/update mod_wl_ohs configuration file based on WebLogic Cluster address
function create_mod_wl_ohs_conf()
{
    getWLSClusterAddress
  
    echo "Creating backup file for existing mod_wl_ohs.conf file"
    runuser -l oracle -c  "mv $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/mod_wl_ohs.conf $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/mod_wl_ohs.conf.bkp"
    runuser -l oracle -c  "mv $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/mod_wl_ohs.conf $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/mod_wl_ohs.conf.bkp"
  
    echo "Creating mod_wl_ohs.conf file as per ${WLS_CLUSTER_ADDRESS}"	
    cat <<EOF > $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/mod_wl_ohs.conf
    LoadModule weblogic_module   "${INSTALL_PATH}/oracle/middleware/oracle_home/ohs/modules/mod_wl_ohs.so"
    <IfModule weblogic_module>
      WLIOTimeoutSecs 900
      KeepAliveSecs 290
      FileCaching ON
      WLSocketTimeoutSecs 15
      DynamicServerList ON
      WLProxySSL ON
      WebLogicCluster ${WLS_CLUSTER_ADDRESS}
    </IfModule>
    <Location / >
      SetHandler weblogic-handler
      DynamicServerList ON
      WLProxySSL ON
      WebLogicCluster  ${WLS_CLUSTER_ADDRESS}
    </Location>
 
EOF
 
    sudo chown -R $username:$groupname $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/mod_wl_ohs.conf
    runuser -l oracle -c  "cp $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/mod_wl_ohs.conf $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/."
}

# Update the network rules so that OHS_HTTP_PORT and OHS_HTTPS_PORT is accessible
function updateNetworkRules()
{
    # for Oracle Linux 7.3, 7.4, iptable is not running.
    if [ -z `command -v firewall-cmd` ]; then
       return 0
    fi
    sudo firewall-cmd --zone=public --add-port=$OHS_HTTP_PORT/tcp
    sudo firewall-cmd --zone=public --add-port=$OHS_HTTPS_PORT/tcp
    sudo firewall-cmd --runtime-to-permanent
    sudo systemctl restart firewalld
    sleep 30s
}

# Oracle Vault needs to be created to add JKS keystore or PKCS12 certificate for OHS
function createOracleVault()
{
    runuser -l oracle -c "mkdir -p ${OHS_VAULT_PATH}"
    runuser -l oracle -c  "${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/bin/orapki wallet create -wallet ${OHS_VAULT_PATH} -pwd ${ORACLE_VAULT_SHIBBOLETH} -auto_login"
    if [[ $? == 0 ]]; 
    then
        echo "Successfully oracle vault is created"
    else
        echo_stderr "Failed to create oracle vault"
        exit 1
    fi	
    ls -lt ${OHS_VAULT_PATH}
}

# Add provided certificates to Oracle vault created
function addCertficateToOracleVault()
{
    ohsKeyStoreData=$(echo "$OHS_KEY_STORE_DATA" | base64 --decode)
    ohsKeyStorePassPhrase=$(echo "$OHS_KEY_STORE_PASSPHRASE" | base64 --decode)

    case "${OHS_KEY_TYPE}" in
      "JKS")
          echo "$ohsKeyStoreData" | base64 --decode > ${OHS_VAULT_PATH}/ohsKeystore.jks
          sudo chown -R $username:$groupname ${OHS_VAULT_PATH}/ohsKeystore.jks
          # Validate JKS file
          verifyCertValidity ${OHS_VAULT_PATH}/ohsKeystore.jks $ohsKeyStorePassPhrase $CURRENT_DATE $MIN_CERT_VALIDITY "JKS" 
          
          KEY_TYPE=`$JAVA_HOME/bin/keytool -list -v -keystore ${OHS_VAULT_PATH}/ohsKeystore.jks -storepass ${ohsKeyStorePassPhrase} | grep 'Keystore type:'`
          if [[ $KEY_TYPE == *"jks"* ]]; then
              runuser -l oracle -c  "${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/bin/orapki wallet  jks_to_pkcs12  -wallet ${OHS_VAULT_PATH}  -pwd ${ORACLE_VAULT_SHIBBOLETH} -keystore ${OHS_VAULT_PATH}/ohsKeystore.jks -jkspwd ${ohsKeyStorePassPhrase}"
              if [[ $? == 0 ]]; then
                 echo "Successfully added JKS keystore to Oracle Wallet"
              else
                 echo_stderr "Adding JKS keystore to Oracle Wallet failed"
                 exit 1
              fi
          else
              echo_stderr "Not a valid JKS keystore file"
              exit 1
          fi
          ;;
  	
     "PKCS12")  	
          echo "$ohsKeyStoreData" | base64 --decode > ${OHS_VAULT_PATH}/ohsCert.p12
          sudo chown -R $username:$groupname ${OHS_VAULT_PATH}/ohsCert.p12
          # Validate PKCS12 file
          verifyCertValidity ${OHS_VAULT_PATH}/ohsCert.p12 $ohsKeyStorePassPhrase $CURRENT_DATE $MIN_CERT_VALIDITY "PKCS12"
          
          runuser -l oracle -c "${INSTALL_PATH}/oracle/middleware/oracle_home/oracle_common/bin/orapki wallet import_pkcs12 -wallet ${OHS_VAULT_PATH} -pwd ${ORACLE_VAULT_SHIBBOLETH} -pkcs12file ${OHS_VAULT_PATH}/ohsCert.p12  -pkcs12pwd ${ohsKeyStorePassPhrase}"
          if [[ $? == 0 ]]; then
              echo "Successfully added certificate to Oracle Wallet"
          else
              echo_stderr "Unable to add PKCS12 certificate to Oracle Wallet"
              exit 1
          fi
     	  ;;
  esac
}

# Update ssl.conf file for SSL access and vault path
function updateSSLConfFile()
{
    echo "Updating ssl.conf file for oracle vaulet"
    runuser -l oracle -c  "cp $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/ssl.conf $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/ssl.conf.bkup"
    runuser -l oracle -c  "cp $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/ssl.conf $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/ssl.conf.bkup"
    runuser -l oracle -c  "sed -i 's|SSLWallet.*|SSLWallet \"${OHS_VAULT_PATH}\"|g' $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/instances/$OHS_COMPONENT_NAME/ssl.conf"
    runuser -l oracle -c  "sed -i 's|SSLWallet.*|SSLWallet \"${OHS_VAULT_PATH}\"|g' $OHS_DOMAIN_PATH/config/fmwconfig/components/OHS/$OHS_COMPONENT_NAME/ssl.conf"
}

#Check whether service is started
function verifyService()
{
    serviceName=$1
    sudo systemctl status $serviceName | grep "active"     
    if [[ $? != 0 ]]; 
    then
        echo "$serviceName is not in active state"
        exit 1
    fi
    echo $serviceName is active and running
}



# Execution starts here

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

# Used for certificate expiry validation
CURRENT_DATE=`date +%s`
# Supplied certificate to have minimum days validity for the deployment
# In this case set for 1 day
MIN_CERT_VALIDITY="1"

read OHS_DOMAIN_NAME OHS_COMPONENT_NAME OHS_NM_USER OHS_NM_SHIBBOLETH OHS_HTTP_PORT OHS_HTTPS_PORT WLS_REST_URL WLS_USER WLS_SHIBBOLETH OHS_KEY_STORE_DATA OHS_KEY_STORE_PASSPHRASE ORACLE_VAULT_SHIBBOLETH OHS_KEY_TYPE

JDK_PATH="/u01/app/jdk"
JDK_VERSION="jdk1.8.0_291"
JAVA_HOME=$JDK_PATH/$JDK_VERSION
PATH=$JAVA_HOME/bin:$PATH
OHS_PATH="/u01/app/ohs"
DOMAIN_PATH="/u01/domains"
INSTALL_PATH="$OHS_PATH/install"
OHS_DOMAIN_PATH=${DOMAIN_PATH}/${OHS_DOMAIN_NAME}
OHS_VAULT_PATH="${DOMAIN_PATH}/ohsvault"
groupname="oracle"
username="oracle"

validateInput
setupDomainPath
setupOHSDomain
createStartComponent
createStopComponent
create_nodemanager_service
createComponentService
create_mod_wl_ohs_conf
createOracleVault
addCertficateToOracleVault
updateSSLConfFile
updateNetworkRules
enabledAndStartNodeManagerService
verifyService "ohs_nodemanager"
enableAndStartOHSServerService
verifyService "ohs_component"
cleanup
