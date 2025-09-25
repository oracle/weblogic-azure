#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to add and configure new managed server node to existing WebLogic domain

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./addnode.sh <<< \"<addNodeSetupArgumentsFromStdIn>\""
}

function installUtilities()
{
    echo "Installing zip unzip wget vnc-server rng-tools cifs-utils"
    sudo yum install -y zip unzip wget vnc-server rng-tools cifs-utils

    #Setting up rngd utils
    attempt=1
    while [[ $attempt -lt 4 ]]
    do
       echo "Starting rngd service attempt $attempt"
       sudo systemctl start rngd
       attempt=`expr $attempt + 1`
       sudo systemctl status rngd | grep running
       if [[ $? == 0 ]]; 
       then
          echo "rngd utility service started successfully"
          break
       fi
       sleep 1m
    done  
}

function validateInput()
{
    if [ -z "$wlsDomainName" ];
    then
        echo_stderr "wlsDomainName is required. "
    fi

    if [[ -z "$wlsUserName" || -z "$wlsShibboleth" ]]
    then
        echo_stderr "Weblogic username or password is required. "
        exit 1
    fi

    if [ -z "$managedServerPrefix" ];
    then
        echo_stderr "managedServerPrefix is required. "
    fi

    if [ -z "$serverIndex" ];
    then
        echo_stderr "serverIndex is required. "
    fi

    wlsServerName=${managedServerPrefix}${serverIndex}

    if [ -z "$wlsAdminURL" ];
    then
        echo_stderr "wlsAdminURL is required. "
    fi

    if [ -z "$oracleHome" ];
    then
        echo_stderr "oracleHome is required. "
    fi

    if [ -z "$wlsDomainPath" ];
    then
        echo_stderr "wlsDomainPath is required. "
    fi

    if [ -z "$storageAccountName" ];
    then
        echo_stderr "storageAccountName is required. "
    fi

    if [ -z "$storageAccountKey" ];
    then
        echo_stderr "storageAccountKey is required. "
    fi

    if [ -z "$mountpointPath" ];
    then
        echo_stderr "mountpointPath is required. "
    fi

     if [[ -z "$wlsADSSLCer" || -z "$wlsLDAPPublicIP"  || -z "$adServerHost" ]]
    then
        echo_stderr "wlsADSSLCer, wlsLDAPPublicIP and adServerHost are required. "
        exit 1
    fi

    if [[ "$wlsADSSLCer" != "null" && "$wlsLDAPPublicIP" != "null" && "$adServerHost" != "null" ]]
    then 
        enableAAD="true"
    fi

    if [ -z "$appGWHostName" ];
    then
        echo_stderr "appGWHostName is required. "
    fi

    if [ -z "$enableELK" ];
    then
        echo_stderr "enableELK is required. "
    fi

    if [ -z "$elasticURI" ];
    then
        echo_stderr "elasticURI is required. "
    fi

    if [ -z "$elasticUserName" ];
    then
        echo_stderr "elasticUserName is required. "
    fi

    if [ -z "$elasticPassword" ];
    then
        echo_stderr "elasticPassword is required. "
    fi

    if [ -z "$logsToIntegrate" ];
    then
        echo_stderr "logsToIntegrate is required. "
    fi

    if [ -z "$logIndex" ];
    then
        echo_stderr "logIndex is required. "
    fi
    
    if [ -z "$enableCoherence" ];
    then
        echo_stderr "enableCoherence is required. "
    fi

    if [ "${isCustomSSLEnabled}" == "true" ];
    then
        if [[ -z "$customIdentityKeyStoreBase64String" || -z "$customIdentityKeyStorePassPhrase"  || -z "$customIdentityKeyStoreType" ||
              -z "$customTrustKeyStoreBase64String" || -z "$customTrustKeyStorePassPhrase"  || -z "$customTrustKeyStoreType" ||
              -z "$privateKeyAlias" || -z "$privateKeyPassPhrase" ]]
        then
            echo_stderr "customIdentityKeyStoreBase64String, customIdentityKeyStorePassPhrase, customIdentityKeyStoreType, customTrustKeyStoreBase64String, customTrustKeyStorePassPhrase, customTrustKeyStoreType, privateKeyAlias and privateKeyPassPhrase are required. "
            exit 1
        fi
    fi
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."
    rm -rf $wlsDomainPath/managed-domain.yaml
    rm -rf $wlsDomainPath/weblogic-deploy.zip
    rm -rf $wlsDomainPath/weblogic-deploy
    rm -rf $wlsDomainPath/*.py
    rm -rf ${CUSTOM_HOSTNAME_VERIFIER_HOME}
    echo "Cleanup completed."
}

#Creates weblogic deployment model for cluster domain managed server
function create_managed_model()
{
    echo "Creating admin domain model"
    cat <<EOF >$wlsDomainPath/managed-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsShibboleth"
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
        '$wlsClusterName':
            MigrationBasis: 'consensus'
   Server:
        '$wlsServerName' :
           ListenPort: $wlsManagedPort
           Notes: "$wlsServerName managed server"
           Cluster: "$wlsClusterName"
           Machine: "$nmHost"
           ServerStart:
               Arguments: '${SERVER_STARTUP_ARGS}'
   SecurityConfiguration:
       NodeManagerUsername: "$wlsUserName"
       NodeManagerPasswordEncrypted: "$wlsShibboleth"
EOF
}

#This function to add machine for a given managed server
function create_machine_model()
{
    echo "Creating machine name model for managed server $wlsServerName"
    cat <<EOF >$wlsDomainPath/add-machine.py
connect('$wlsUserName','$wlsShibboleth','t3://$wlsAdminURL')
edit("$wlsServerName")
startEdit()
cd('/')
cmo.createMachine('$nmHost')
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
function create_ms_server_model()
{
    echo "Creating managed server $wlsServerName model"

    cat <<EOF >$wlsDomainPath/add-server.py

isCustomSSLEnabled='${isCustomSSLEnabled}'

connect('$wlsUserName','$wlsShibboleth','t3://$wlsAdminURL')
edit("$wlsServerName")
startEdit()
cd('/')
cmo.createServer('$wlsServerName')
cd('/Servers/$wlsServerName')
cmo.setMachine(getMBean('/Machines/$nmHost'))
cmo.setCluster(getMBean('/Clusters/$wlsClusterName'))
cmo.setListenAddress('$nmHost')
cmo.setListenPort(int($wlsManagedPort))
cmo.setListenPortEnabled(true)

if isCustomSSLEnabled == 'true' :
    cmo.setKeyStores('CustomIdentityAndCustomTrust')
    cmo.setCustomIdentityKeyStoreFileName('$customSSLIdentityKeyStoreFile')
    cmo.setCustomIdentityKeyStoreType('$customIdentityKeyStoreType')
    set('CustomIdentityKeyStorePassPhrase', '$customIdentityKeyStorePassPhrase')
    cmo.setCustomTrustKeyStoreFileName('$customSSLTrustKeyStoreFile')
    cmo.setCustomTrustKeyStoreType('$customTrustKeyStoreType')
    set('CustomTrustKeyStorePassPhrase', '$customTrustKeyStorePassPhrase')

    cd('/Servers/$wlsServerName/SSL/$wlsServerName')
    cmo.setServerPrivateKeyAlias('$privateKeyAlias')
    set('ServerPrivateKeyPassPhrase', '$privateKeyPassPhrase')

cd('/Servers/$wlsServerName/ServerStart/$wlsServerName')
arguments = '${SERVER_STARTUP_ARGS} -Dweblogic.Name=$wlsServerName '
oldArgs = cmo.getArguments()
if oldArgs != None:
  newArgs = oldArgs + ' ' + arguments
else:
  newArgs = arguments
cmo.setArguments(newArgs)
EOF

    if [ "$appGWHostName" != "null" ]; then
    cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName')
create('T3Channel','NetworkAccessPoint')
cd('/Servers/$wlsServerName/NetworkAccessPoints/T3Channel')
set('Protocol','t3')
set('ListenAddress','')
set('ListenPort',$channelPort)
set('PublicAddress', '$appGWHostName')
set('PublicPort', $channelPort)
set('Enabled','true')

cd('/Servers/$wlsServerName')
create('HTTPChannel','NetworkAccessPoint')
cd('/Servers/$wlsServerName/NetworkAccessPoints/HTTPChannel')
set('Protocol','http')
set('ListenAddress','')
set('ListenPort',$channelPort)
set('PublicAddress', '$appGWHostName')
set('PublicPort', $channelPort)
set('Enabled','true')
EOF
    fi

cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName/SSL/$wlsServerName')
cmo.setEnabled(false)
EOF

    if [ "${enableAAD}" == "true" ]; then
    cat <<EOF >>$wlsDomainPath/add-server.py
#need to revisit this as HostNameVerification is not supported
#cmo.setHostnameVerificationIgnored(true)
EOF
    fi

    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    ${JAVA_HOME}/bin/java -version  2>&1  | grep -e "1[.]8[.][0-9]*_"  > /dev/null 
    java8Status=$?
    if [ "${java8Status}" == "0" ]; then
    cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName//ServerStart/$wlsServerName')
arguments = '-Dweblogic.Name=$wlsServerName  -Dweblogic.management.server=http://$wlsAdminURL -Djdk.tls.client.protocols=TLSv1.2'
EOF
else
    cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName//ServerStart/$wlsServerName')
arguments = '-Dweblogic.Name=$wlsServerName  -Dweblogic.management.server=http://$wlsAdminURL'
EOF
    fi

    if [[ "${enableELK,,}" == "true" ]]; then
    cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName/WebServer/$wlsServerName/WebServerLog/$wlsServerName')
cmo.setLogFileFormat('extended')
cmo.setELFFields('date time time-taken bytes c-ip  s-ip c-dns s-dns  cs-method cs-uri sc-status sc-comment ctx-ecid ctx-rid') 

cd('/Servers/$wlsServerName/Log/$wlsServerName')
cmo.setRedirectStderrToServerLogEnabled(true)
cmo.setRedirectStdoutToServerLogEnabled(true)
cmo.setStdoutLogStack(true)
EOF
    fi

    if [[ "${enableCoherence,,}" == "true" ]]; then
        cat <<EOF >>$wlsDomainPath/add-server.py
arguments = arguments + ' -Dcoherence.localport=$coherenceLocalport -Dcoherence.localport.adjust=$coherenceLocalportAdjust'
EOF
    fi

    cat <<EOF >>$wlsDomainPath/add-server.py
cd('/Servers/$wlsServerName//ServerStart/$wlsServerName')
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

#This function to wait for admin server 
function wait_for_admin()
{
 #wait for admin to start
count=1
CHECK_URL="http://$wlsAdminURL/weblogic/ready"
status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
echo "Waiting for admin server to start"
while [[ "$status" != "200" ]]
do
  echo "."
  count=$((count+1))
  if [ $count -le 30 ];
  then
      sleep 1m
  else
     echo "Error : Maximum attempts exceeded while starting admin server"
     exit 1
  fi
  status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
  if [ "$status" == "200" ];
  then
     echo "Server $wlsServerName started succesfully..."
     break
  fi
done  
}

# Create systemctl service for nodemanager
function create_nodemanager_service()
{
 echo "Setting CrashRecoveryEnabled true at $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties"
 sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g'  $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
 if [ $? != 0 ];
 then
   echo "Warning : Failed in setting option CrashRecoveryEnabled=true. Continuing without the option."
   mv $wlsDomainPath/nodemanager/nodemanager.properties.bak $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
 fi

if [ "${isCustomSSLEnabled}" == "true" ];
then
    echo "KeyStores=CustomIdentityAndCustomTrust" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeystoreType=${customIdentityKeyStoreType}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeyStoreFileName=${customSSLIdentityKeyStoreFile}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeyStorePassPhrase=${customIdentityKeyStorePassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityAlias=${privateKeyAlias}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityPrivateKeyPassPhrase=${privateKeyPassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeystoreType=${customTrustKeyStoreType}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeyStoreFileName=${customSSLTrustKeyStoreFile}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeyStorePassPhrase=${customTrustKeyStorePassPhrase}" >> $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties
fi

 sudo chown -R $username:$groupname $wlsDomainPath/$wlsDomainName/nodemanager/nodemanager.properties*
 echo "Creating NodeManager service"
 cat <<EOF >/etc/systemd/system/wls_nodemanager.service
 [Unit]
Description=WebLogic nodemanager service
 
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
 
[Install]
WantedBy=multi-user.target
EOF
}

#This function to start managed server
function start_managed()
{
    echo "Starting managed server $wlsServerName"
    cat <<EOF >$wlsDomainPath/start-server.py
connect('$wlsUserName','$wlsShibboleth','t3://$wlsAdminURL')
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
function create_managedSetup(){
    echo "Creating Managed Server Setup"
    cd $wlsDomainPath
    wget -q $WEBLOGIC_DEPLOY_TOOL  
    if [[ $? != 0 ]]; then
       echo "Error : Downloading weblogic-deploy-tool failed"
       exit 1
    fi
    sudo unzip -o weblogic-deploy.zip -d $wlsDomainPath
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

function enabledAndStartNodeManagerService()
{
  sudo systemctl enable wls_nodemanager
  sudo systemctl daemon-reload
  attempt=1
  while [[ $attempt -lt 6 ]]
  do
     echo "Starting nodemanager service attempt $attempt"
     sudo systemctl start wls_nodemanager
     attempt=`expr $attempt + 1`
     sudo systemctl status wls_nodemanager | grep running
     if [[ $? == 0 ]]; 
     then
         echo "wls_nodemanager service started successfully"
	 break
     fi
     sleep 3m
 done
}

function updateNetworkRules()
{
    # for Oracle Linux 7.3, 7.4, iptable is not running.
    if [ -z `command -v firewall-cmd` ]; then
        return 0
    fi
    
    # for Oracle Linux 7.6, open weblogic ports
    tag=$1
    if [ ${tag} == 'admin' ]; then
        echo "update network rules for admin server"
        sudo firewall-cmd --zone=public --add-port=$wlsAdminPort/tcp
        sudo firewall-cmd --zone=public --add-port=$wlsAdminChannelPort/tcp
        sudo firewall-cmd --zone=public --add-port=$wlsSSLAdminPort/tcp
        sudo firewall-cmd --zone=public --add-port=$wlsManagedPort/tcp
        sudo firewall-cmd --zone=public --add-port=$nmPort/tcp
    else
        echo "update network rules for managed server"
        sudo firewall-cmd --zone=public --add-port=$wlsManagedPort/tcp
        sudo firewall-cmd --zone=public --add-port=$nmPort/tcp

        # open ports for coherence
        sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/tcp
        sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/udp
        sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/tcp
        sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/udp
        sudo firewall-cmd --zone=public --add-port=7/tcp
    fi

    sudo firewall-cmd --runtime-to-permanent
    sudo systemctl restart firewalld
}

# Mount the Azure file share on all VMs created
function mountFileShare()
{
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
  if [[ $? != 0 ]];
  then
         echo "Failed to mount //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath"
	 exit 1
  fi
}

# Get SerializedSystemIni.dat file from share point to managed server vm
function getSerializedSystemIniFileFromShare()
{
  runuser -l oracle -c "mv ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat.backup"
  runuser -l oracle -c "cp ${mountpointPath}/SerializedSystemIni.dat ${wlsDomainPath}/${wlsDomainName}/security/."
  ls -lt ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat
  if [[ $? != 0 ]]; 
  then
      echo "Failed to get ${mountpointPath}/SerializedSystemIni.dat"
      exit 1
  fi
  runuser -l oracle -c "chmod 640 ${wlsDomainPath}/${wlsDomainName}/security/SerializedSystemIni.dat"
}

function mapLDAPHostWithPublicIP()
{
    echo "map LDAP host with pubilc IP"
    
    # remove existing ip address for the same host
    sudo sed -i '/${adServerHost}/d' /etc/hosts
    sudo echo "${wlsLDAPPublicIP}  ${adServerHost}" >> /etc/hosts
}

function parseLDAPCertificate()
{
    echo "create key store"
    cer_begin=0
    cer_size=${#wlsADSSLCer}
    cer_line_len=64
    mkdir ${SCRIPT_PWD}/security
    touch ${SCRIPT_PWD}/security/AzureADLDAPCerBase64String.txt
    while [ ${cer_begin} -lt ${cer_size} ]
    do
        cer_sub=${wlsADSSLCer:$cer_begin:$cer_line_len}
        echo ${cer_sub} >> ${SCRIPT_PWD}/security/AzureADLDAPCerBase64String.txt
        cer_begin=$((cer_begin+$cer_line_len))
    done

    openssl base64 -d -in ${SCRIPT_PWD}/security/AzureADLDAPCerBase64String.txt -out ${SCRIPT_PWD}/security/AzureADTrust.cer
    addsCertificate=${SCRIPT_PWD}/security/AzureADTrust.cer
}

function importAADCertificate()
{
    # import the key to java security 
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    # For Entra ID failure: exception happens when importing certificate to JDK 11.0.7
    # ISSUE: https://github.com/wls-eng/arm-oraclelinux-wls/issues/109
    # JRE was removed since JDK 11.
    java_version=$(java -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
    if [ ${java_version:0:3} -ge 110 ]; 
    then 
        java_cacerts_path=${JAVA_HOME}/lib/security/cacerts
    else
        java_cacerts_path=${JAVA_HOME}/jre/lib/security/cacerts
    fi

    # remove existing certificate.
    queryAADTrust=$(${JAVA_HOME}/bin/keytool -list -keystore ${java_cacerts_path} -storepass changeit | grep "aadtrust")
    if [ -n "${queryAADTrust}" ];
    then
        sudo ${JAVA_HOME}/bin/keytool -delete -alias aadtrust -keystore ${java_cacerts_path} -storepass changeit  
    fi

    sudo ${JAVA_HOME}/bin/keytool -noprompt -import -alias aadtrust -file ${addsCertificate} -keystore ${java_cacerts_path} -storepass changeit
}

function importAADCertificateIntoWLSCustomTrustKeyStore()
{
    if [ "${isCustomSSLEnabled,,}" == "true" ];
    then
        # set java home
        . $oracleHome/oracle_common/common/bin/setWlstEnv.sh

        #validate Trust keystore
        runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customSSLTrustKeyStoreFile -storepass $customTrustKeyStorePassPhrase -storetype $customTrustKeyStoreType | grep 'Entry type:' | grep 'trustedCertEntry'"

        if [[ $? != 0 ]]; then
            echo "Error : Trust Keystore Validation Failed !!"
            exit 1
        fi

        # For SSL enabled causes Entra ID failure #225
        # ISSUE: https://github.com/wls-eng/arm-oraclelinux-wls/issues/225

        echo "Importing Entra ID Certificate into WLS Custom Trust Key Store: "

        sudo ${JAVA_HOME}/bin/keytool -noprompt -import -trustcacerts -keystore {KEYSTORE_PATH}/trust.keystore -storepass ${customTrustKeyStorePassPhrase} -alias aadtrust -file ${addsCertificate} -storetype ${customTrustKeyStoreType}
    else
        echo "customSSL not enabled. Not required to configure Entra ID for WebLogic Custom SSL"
    fi
}

function validateSSLKeyStores()
{
   sudo chown -R $username:$groupname $KEYSTORE_PATH

   #validate identity keystore
   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customSSLIdentityKeyStoreFile -storepass $customIdentityKeyStorePassPhrase -storetype $customIdentityKeyStoreType | grep 'Entry type:' | grep 'PrivateKeyEntry'"

   if [[ $? != 0 ]]; then
       echo "Error : Identity Keystore Validation Failed !!"
       exit 1
   fi

   #validate Trust keystore
   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customSSLTrustKeyStoreFile -storepass $customTrustKeyStorePassPhrase -storetype $customTrustKeyStoreType | grep 'Entry type:' | grep 'trustedCertEntry'"

   if [[ $? != 0 ]]; then
       echo "Error : Trust Keystore Validation Failed !!"
       exit 1
   fi

   echo "ValidateSSLKeyStores Successfull !!"
}

function parseAndSaveCustomSSLKeyStoreData()
{
    echo "create key stores for custom ssl settings"

    mkdir -p ${KEYSTORE_PATH}
    touch ${KEYSTORE_PATH}/identityKeyStoreCerBase64String.txt

    echo "$customIdentityKeyStoreBase64String" > ${KEYSTORE_PATH}/identityKeyStoreCerBase64String.txt
    cat ${KEYSTORE_PATH}/identityKeyStoreCerBase64String.txt | base64 -d > ${KEYSTORE_PATH}/identity.keystore
    customSSLIdentityKeyStoreFile=${KEYSTORE_PATH}/identity.keystore
    customIdentityKeyStorePassPhrase="$(echo $customIdentityKeyStorePassPhrase | base64 --decode)"

    rm -rf ${KEYSTORE_PATH}/identityKeyStoreCerBase64String.txt

    mkdir -p ${KEYSTORE_PATH}
    touch ${KEYSTORE_PATH}/trustKeyStoreCerBase64String.txt

    echo "$customTrustKeyStoreBase64String" > ${KEYSTORE_PATH}/trustKeyStoreCerBase64String.txt
    cat ${KEYSTORE_PATH}/trustKeyStoreCerBase64String.txt | base64 -d > ${KEYSTORE_PATH}/trust.keystore
    customSSLTrustKeyStoreFile=${KEYSTORE_PATH}/trust.keystore
    customTrustKeyStorePassPhrase="$(echo $customTrustKeyStorePassPhrase | base64 --decode)"

    rm -rf ${KEYSTORE_PATH}/trustKeyStoreCerBase64String.txt

    privateKeyAlias="$(echo $privateKeyAlias | base64 --decode)"
    privateKeyPassPhrase="$(echo $privateKeyPassPhrase | base64 --decode)"

    validateSSLKeyStores
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

   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; ${CUSTOM_HOSTNAME_VERIFIER_HOME}/generateCustomHostNameVerifier.sh ${wlsAdminHost} ${customDNSNameForAdminServer} ${customDNSNameForAdminServer} ${dnsLabelPrefix} ${wlsDomainName} ${location}"
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
    cat <<EOF >${wlsDomainPath}/configureCustomHostNameVerifier.py
connect('$wlsUserName','$wlsShibboleth','t3://$wlsAdminURL')
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
sudo chown -R $username:$groupname ${wlsDomainPath}
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${wlsDomainPath}/configureCustomHostNameVerifier.py"
if [[ $? != 0 ]]; then
  echo "Error : Failed to configureCustomHostNameVerifier for domain $wlsDomainName"
  exit 1
fi

}

#main script starts here

SCRIPT_PWD=`pwd`
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

#read arguments from stdin
read wlsDomainName wlsUserName wlsShibboleth managedServerPrefix serverIndex wlsAdminURL wlsAdminHost oracleHome wlsDomainPath storageAccountName storageAccountKey mountpointPath wlsADSSLCer wlsLDAPPublicIP adServerHost appGWHostName enableELK elasticURI elasticUserName elasticPassword logsToIntegrate logIndex enableCoherence customDNSNameForAdminServer dnsLabelPrefix location isCustomSSLEnabled customIdentityKeyStoreBase64String customIdentityKeyStorePassPhrase customIdentityKeyStoreType customTrustKeyStoreBase64String customTrustKeyStorePassPhrase customTrustKeyStoreType privateKeyAlias privateKeyPassPhrase

isCustomSSLEnabled="${isCustomSSLEnabled,,}"

coherenceListenPort=7574
coherenceLocalport=42000
coherenceLocalportAdjust=42200
enableAAD="false"
wlsAdminPort=7001
wlsAdminChannelPort=7005
wlsManagedPort=8001
wlsClusterName="cluster1"
nmHost=`hostname`
nmPort=5556
channelPort=8501
AppGWHttpPort=80
AppGWHttpsPort=443
WEBLOGIC_DEPLOY_TOOL=https://github.com/oracle/weblogic-deploy-tooling/releases/download/weblogic-deploy-tooling-1.8.1/weblogic-deploy.zip
username="oracle"
groupname="oracle"
CUSTOM_HOSTNAME_VERIFIER_HOME="/u01/app/custom-hostname-verifier"
KEYSTORE_PATH="$wlsDomainPath/$wlsDomainName/keystores"
SERVER_STARTUP_ARGS="-Dlog4j2.formatMsgNoLookups=true"

chmod ugo+x ${SCRIPT_PWD}/elkIntegration.sh

validateInput
cleanup
installUtilities
mountFileShare
updateNetworkRules "managed"

if [ "$isCustomSSLEnabled" == "true" ];then
    parseAndSaveCustomSSLKeyStoreData
fi

if [ "$enableAAD" == "true" ];then
    mapLDAPHostWithPublicIP
    parseLDAPCertificate
    importAADCertificate
    importAADCertificateIntoWLSCustomTrustKeyStore
fi

create_managedSetup
generateCustomHostNameVerifier
copyCustomHostNameVerifierJarsToWebLogicClasspath
create_nodemanager_service
enabledAndStartNodeManagerService
configureCustomHostNameVerifier
start_managed

echo "enable ELK? ${enableELK}"
if [[ "${enableELK,,}" == "true" ]];then
    echo "Set up ELK..."
    ${SCRIPT_PWD}/elkIntegration.sh \
        ${oracleHome} \
        ${wlsAdminURL} \
        ${wlsUserName} \
        ${wlsShibboleth} \
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

cleanup
