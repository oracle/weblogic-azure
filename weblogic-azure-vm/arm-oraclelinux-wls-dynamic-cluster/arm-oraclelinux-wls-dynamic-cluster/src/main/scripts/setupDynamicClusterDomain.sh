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
  echo_stderr "./setDynamicClusterDomain.sh"
}

function installUtilities()
{
    echo "Installing zip unzip wget vnc-server rng-tools cifs-utils"
    sudo yum install -y zip unzip wget vnc-server rng-tools cifs-utils

    #Setting up rngd utils
    sudo systemctl status rngd
    sudo systemctl start rngd
    sudo systemctl status rngd
}

function validateInput()
{
  if [ -z "$wlsDomainName" ];
  then
    echo_stderr "wlsDomainName is required. "
  fi

  if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]
  then
    echo_stderr "wlsUserName or wlsPassword is required. "
    exit 1
  fi	

  if [ -z "$managedServerPrefix" ];
  then
    echo_stderr "managedServerPrefix is required. "
    exit 1
  fi

  if [ -z "$maxDynamicClusterSize" ];
  then
    echo_stderr "maxDynamicClusterSize is required. "
    exit 1
  fi

  if [ -z "$dynamicClusterSize" ];
  then
    echo_stderr "dynamicClusterSize is required. "
    exit 1
  fi


  if [ -z "$vmNamePrefix" ];
  then
    echo_stderr "vmNamePrefix is required. "
    exit 1
  fi

  if [ -z "$adminVMName" ];
  then
    echo_stderr "adminVMName is required. "
    exit 1
  fi

  if [ -z "$oracleHome" ];
  then
    echo_stderr "oracleHome is required"
    exit 1
  fi

  if [ -z "$storageAccountName" ];
    then 
        echo_stderr "storageAccountName is required. "
        exit 1
    fi
    
    if [ -z "$storageAccountKey" ];
    then 
        echo_stderr "storageAccountKey is required. "
        exit 1
    fi
    
    if [ -z "$mountpointPath" ];
    then 
        echo_stderr "mountpointPath is required. "
        exit 1
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

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."
    rm -rf $DOMAIN_PATH/admin-domain.yaml
    rm -rf $DOMAIN_PATH/managed-domain.yaml
    rm -rf $DOMAIN_PATH/weblogic-deploy.zip
    rm -rf $DOMAIN_PATH/weblogic-deploy
    rm -rf $DOMAIN_PATH/deploy-app.yaml
    rm -rf $DOMAIN_PATH/shoppingcart.zip
    rm -rf $DOMAIN_PATH/*.py
    echo "Cleanup completed."
}

#Creates weblogic deployment model for admin domain
function create_admin_model()
{
    echo "Creating admin domain model"
    cat /dev/null > $DOMAIN_PATH/admin-domain.yaml

    cat <<EOF >$DOMAIN_PATH/admin-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   AdminServerName: admin
   Machine:
     '$nmHost':
         NodeManager:
             ListenAddress: "$nmHost"
             ListenPort: $nmPort
             NMType : ssl
   Server:
        '$wlsServerName':
            ListenPort: $wlsAdminPort
            ListenPortEnabled: ${isHTTPAdminListenPortEnabled}
            RestartDelaySeconds: 10
            NetworkAccessPoint:
               'adminT3Channel':
                   ListenAddress: '$adminVMName'
                   ListenPort: $wlsAdminT3ChannelPort
                   Protocol: t3
                   Enabled: true
            SSL:
               ListenPort: $wlsSSLAdminPort
               Enabled: true
               HostnameVerificationIgnored: true
               HostnameVerifier: 'None'
EOF

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
               ServerPrivateKeyAlias: "$serverPrivateKeyAlias"
               ServerPrivateKeyPassPhraseEncrypted: "$serverPrivateKeyPassPhrase"
EOF
        fi

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
            KeyStores: 'CustomIdentityAndCustomTrust'
            CustomIdentityKeyStoreFileName: "$customIdentityKeyStoreFileName"
            CustomIdentityKeyStoreType: "$customIdentityKeyStoreType"
            CustomIdentityKeyStorePassPhraseEncrypted: "$customIdentityKeyStorePassPhrase"
            CustomTrustKeyStoreFileName: "$customTrustKeyStoreFileName"
            CustomTrustKeyStoreType: "$customTrustKeyStoreType"
            CustomTrustKeyStorePassPhraseEncrypted: "$customTrustKeyStorePassPhrase"
EOF
        fi

    cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
   Cluster:
        '$wlsClusterName':
            MigrationBasis: 'consensus'
            DynamicServers:
                ServerTemplate: '${dynamicServerTemplate}'
                DynamicClusterSize: ${dynamicClusterSize}
                MaxDynamicClusterSize: ${maxDynamicClusterSize}
                CalculatedListenPorts: true
                CalculatedMachineNames: true
                ServerNamePrefix: "${managedServerPrefix}"
                MachineNameMatchExpression: "$machineNamePrefix-${vmNamePrefix}*"
   ServerTemplate:
        '${dynamicServerTemplate}' :
            ListenPort: ${wlsManagedPort}
            Cluster: '${wlsClusterName}'
            SSL:
                HostnameVerificationIgnored: true
                HostnameVerifier: 'None'
EOF

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
                ServerPrivateKeyAlias: "$serverPrivateKeyAlias"
                ServerPrivateKeyPassPhraseEncrypted: "$serverPrivateKeyPassPhrase"
EOF
        fi

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
            KeyStores: 'CustomIdentityAndCustomTrust'
            CustomIdentityKeyStoreFileName: "$customIdentityKeyStoreFileName"
            CustomIdentityKeyStoreType: "$customIdentityKeyStoreType"
            CustomIdentityKeyStorePassPhraseEncrypted: "$customIdentityKeyStorePassPhrase"
            CustomTrustKeyStoreFileName: "$customTrustKeyStoreFileName"
            CustomTrustKeyStoreType: "$customTrustKeyStoreType"
            CustomTrustKeyStorePassPhraseEncrypted: "$customTrustKeyStorePassPhrase"
EOF
        fi

cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
   SecurityConfiguration:
        NodeManagerUsername: "$wlsUserName"
        NodeManagerPasswordEncrypted: "$wlsPassword"
EOF
}

#Creates weblogic deployment model for admin domain
function create_managed_model()
{
    echo "Creating admin domain model"
    cat <<EOF >$DOMAIN_PATH/managed-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   Machine:
     '$machineName':
         NodeManager:
            ListenAddress: "$nmHost"
            ListenPort: $nmPort
            NMType: "ssl"
   Cluster:
        '$wlsClusterName':
            MigrationBasis: 'consensus'
            DynamicServers:
                ServerTemplate: '${dynamicServerTemplate}'
                DynamicClusterSize: ${dynamicClusterSize}
                MaxDynamicClusterSize: ${maxDynamicClusterSize}
                CalculatedListenPorts: true
                CalculatedMachineNames: true
                ServerNamePrefix: "${managedServerPrefix}"
                MachineNameMatchExpression: "machine-${vmNamePrefix}*"
   ServerTemplate:
        '${dynamicServerTemplate}':
            ListenPort: ${wlsManagedPort}
            Cluster: '${wlsClusterName}'
            SSL:
                HostnameVerificationIgnored: true
                HostnameVerifier: 'None'
EOF
        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/managed-domain.yaml
                ServerPrivateKeyAlias: "$serverPrivateKeyAlias"
                ServerPrivateKeyPassPhraseEncrypted: "$serverPrivateKeyPassPhrase"
EOF
        fi

        if [ "${isCustomSSLEnabled}" == "true" ];
        then
cat <<EOF>>$DOMAIN_PATH/managed-domain.yaml
            KeyStores: 'CustomIdentityAndCustomTrust'
            CustomIdentityKeyStoreFileName: "$customIdentityKeyStoreFileName"
            CustomIdentityKeyStoreType: "$customIdentityKeyStoreType"
            CustomIdentityKeyStorePassPhraseEncrypted: "$customIdentityKeyStorePassPhrase"
            CustomTrustKeyStoreFileName: "$customTrustKeyStoreFileName"
            CustomTrustKeyStoreType: "$customTrustKeyStoreType"
            CustomTrustKeyStorePassPhraseEncrypted: "$customTrustKeyStorePassPhrase"
EOF
        fi

cat <<EOF>>$DOMAIN_PATH/managed-domain.yaml
   SecurityConfiguration:
        NodeManagerUsername: "$wlsUserName"
        NodeManagerPasswordEncrypted: "$wlsPassword"
EOF
}

# This function to create model for sample application deployment 
function create_app_deploy_model()
{

    echo "Creating deploying applicaton model"
    cat <<EOF >$DOMAIN_PATH/deploy-app.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
appDeployments:
   Application:
     shoppingcart :
          SourcePath: "$DOMAIN_PATH/shoppingcart.war"
          Target: '${wlsClusterName}'
          ModuleType: war
EOF
}

#This function create py Script to create Machine on the Domain
function createMachinePyScript()
{

# Exclusive lock is used for startEdit, without that intermittently it is noticed that deployment fails
# Refer issue https://github.com/wls-eng/arm-oraclelinux-wls/issues/280

    echo "Creating machine name model: $machineName"
    cat <<EOF >$DOMAIN_PATH/add-machine.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')

try:
    shutdown('$wlsClusterName','Cluster')
except Exception, e:
    print e

edit()
startEdit(60000,60000,'true')
cd('/')
cmo.createMachine('$machineName')
cd('/Machines/$machineName/NodeManager/$machineName')
cmo.setListenPort(int($nmPort))
cmo.setListenAddress('$nmHost')
cmo.setNMType('ssl')
save()
activate()
disconnect()
EOF
}

#This function creates py Script to enroll Node Manager to the Domain
function createEnrollServerPyScript()
{
    echo "Creating managed server $wlsServerName model"
    cat <<EOF >$DOMAIN_PATH/enroll-server.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
nmEnroll('$DOMAIN_PATH/$wlsDomainName','$DOMAIN_PATH/$wlsDomainName/nodemanager')
nmGenBootStartupProps('$wlsServerName')
disconnect()
EOF
}


#Function to create Admin Only Domain
function create_adminSetup()
{
    echo "Creating Admin Setup"
    echo "Creating domain path $DOMAIN_PATH"
 
    sudo mkdir -p $DOMAIN_PATH 
    sudo rm -rf $DOMAIN_PATH/*

    echo "Downloading weblogic-deploy-tool"
    cd $DOMAIN_PATH
    wget -q $WEBLOGIC_DEPLOY_TOOL  
    if [[ $? != 0 ]]; then
       echo "Error : Downloading weblogic-deploy-tool failed"
       exit 1
    fi
    sudo unzip -o weblogic-deploy.zip -d $DOMAIN_PATH

    storeCustomSSLCerts

    create_admin_model
    sudo chown -R $username:$groupname $DOMAIN_PATH
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $DOMAIN_PATH  -domain_type WLS -model_file $DOMAIN_PATH/admin-domain.yaml" 
    if [[ $? != 0 ]]; then
       echo "Error : Admin setup failed"
       exit 1
    fi

    # For issue https://github.com/wls-eng/arm-oraclelinux-wls/issues/89
    copySerializedSystemIniFileToShare
}

#Function to start admin server
function start_admin()
{
 #Create the boot.properties directory
 mkdir -p "$DOMAIN_PATH/$wlsDomainName/servers/admin/security"
 echo "username=$wlsUserName" > "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 echo "password=$wlsPassword" >> "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 sudo chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/servers
 runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; \"$DOMAIN_PATH/$wlsDomainName/startWebLogic.sh\"  > "$DOMAIN_PATH/$wlsDomainName/admin.out" 2>&1 &"
 sleep 3m
 wait_for_admin
}

#Function to setup admin boot properties
function admin_boot_setup()
{
 echo "Creating admin boot properties"
 #Create the boot.properties directory
 mkdir -p "$DOMAIN_PATH/$wlsDomainName/servers/admin/security"
 echo "username=$wlsUserName" > "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 echo "password=$wlsPassword" >> "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 sudo chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/servers
 }

#This function to wait for admin server 
function wait_for_admin()
{
 #wait for admin to start
count=1
CHECK_URL="http://$wlsAdminURL/weblogic/ready"
status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
while [[ "$status" != "200" ]]
do
  echo "Waiting for admin server to start"
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

#This function to start managed server
function start_cluster()
{
    echo "Starting managed server $wlsServerName"
    cat <<EOF >$DOMAIN_PATH/start-cluster.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
   start('$wlsClusterName', 'Cluster')
except:
   print "Failed starting Cluster $wlsClusterName"
   dumpStack()
disconnect()   
EOF
sudo chown -R $username:$groupname $DOMAIN_PATH
runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/start-cluster.py"
if [[ $? != 0 ]]; then
  echo "Error : Failed in starting Cluster $wlsClusterName"
  exit 1
fi
}

#Function to start nodemanager
function start_nm()
{
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; \"$DOMAIN_PATH/$wlsDomainName/bin/startNodeManager.sh\" &"
    sleep 1m
}

function create_managedSetup(){
    echo "Creating Managed Server Setup"
    echo "Creating domain path /u01/domains"
    DOMAIN_PATH="/u01/domains" 
    sudo mkdir -p $DOMAIN_PATH 
    sudo rm -rf $DOMAIN_PATH/*

    echo "Downloading weblogic-deploy-tool"
    cd $DOMAIN_PATH
    wget -q $WEBLOGIC_DEPLOY_TOOL  
    if [[ $? != 0 ]]; then
       echo "Error : Downloading weblogic-deploy-tool failed"
       exit 1
    fi
    sudo unzip -o weblogic-deploy.zip -d $DOMAIN_PATH

    storeCustomSSLCerts

    echo "Creating managed server model files"
    create_managed_model
    createMachinePyScript
    createEnrollServerPyScript
    echo "Completed managed server model files"
    sudo chown -R $username:$groupname $DOMAIN_PATH
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $DOMAIN_PATH  -domain_type WLS -model_file $DOMAIN_PATH/managed-domain.yaml" 
    if [[ $? != 0 ]]; then
       echo "Error : Managed setup failed"
       exit 1
    fi
    wait_for_admin

    # For issue https://github.com/wls-eng/arm-oraclelinux-wls/issues/89
    getSerializedSystemIniFileFromShare
    echo "Adding machine to managed server $wlsServerName"
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/add-machine.py"
    if [[ $? != 0 ]]; then
         echo "Error : Adding machine for managed server $wlsServerName failed"
         exit 1
    fi
    echo "Enrolling Domain for Managed server $wlsServerName"
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST $DOMAIN_PATH/enroll-server.py"
    if [[ $? != 0 ]]; then
         echo "Error : Adding server $wlsServerName failed"
         exit 1
    fi
}

# Create systemctl service for nodemanager
function create_nodemanager_service()
{
 echo "Creating services for Nodemanager"
 echo "Setting CrashRecoveryEnabled true at $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties"
 sed -i.bak -e 's/CrashRecoveryEnabled=false/CrashRecoveryEnabled=true/g'  $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties

 sed -i.bak -e 's/ListenAddress=.*/ListenAddress=/g'  $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties

if [ "${isCustomSSLEnabled}" == "true" ];
then
    echo "KeyStores=CustomIdentityAndCustomTrust" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeystoreType=${customIdentityKeyStoreType}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeyStoreFileName=${customIdentityKeyStoreFileName}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityKeyStorePassPhrase=${customIdentityKeyStorePassPhrase}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityAlias=${serverPrivateKeyAlias}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomIdentityPrivateKeyPassPhrase=${serverPrivateKeyPassPhrase}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeystoreType=${customTrustKeyStoreType}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeyStoreFileName=${customTrustKeyStoreFileName}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
    echo "CustomTrustKeyStorePassPhrase=${customTrustKeyStorePassPhrase}" >> $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
fi

 if [ $? != 0 ];
 then
   echo "Warning : Failed in setting option CrashRecoveryEnabled=true. Continuing without the option."
   mv $DOMAIN_PATH/nodemanager/nodemanager.properties.bak $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties
 fi

 sudo chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/nodemanager/nodemanager.properties*
 echo "Creating NodeManager service"
 cat <<EOF >/etc/systemd/system/wls_nodemanager.service
 [Unit]
Description=WebLogic nodemanager service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# Note that the following three parameters should be changed to the correct paths
# on your own system
WorkingDirectory="$DOMAIN_PATH/$wlsDomainName"
ExecStart="$DOMAIN_PATH/$wlsDomainName/bin/startNodeManager.sh"
ExecStop="$DOMAIN_PATH/$wlsDomainName/bin/stopNodeManager.sh"
User=oracle
Group=oracle
KillMode=process
LimitNOFILE=65535
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
echo "Created service for Nodemanager"
}

# This function to create adminserver service
function create_adminserver_service()
{
 echo "Creating admin server service"
 cat <<EOF >/etc/systemd/system/wls_admin.service
[Unit]
Description=WebLogic Adminserver service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory="$DOMAIN_PATH/$wlsDomainName"
ExecStart="${startWebLogicScript}"
ExecStop="${stopWebLogicScript}"
User=oracle
Group=oracle
KillMode=process
LimitNOFILE=65535
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
echo "Created services for Admin Server"
}

function enableAndStartAdminServerService()
{
  sudo systemctl enable wls_admin
  sudo systemctl daemon-reload
  echo "Starting admin server service"
  sudo systemctl start wls_admin  

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
     sleep 1m
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
        sudo firewall-cmd --zone=public --add-port=$wlsSSLAdminPort/tcp
        sudo firewall-cmd --zone=public --add-port=$wlsAdminT3ChannelPort/tcp
        sudo firewall-cmd --zone=public --add-port=$nmPort/tcp
    else
        maxManagedIndex=1
        echo "update network rules for managed server"
        # Port is dynamic betweent 8002 to 8001+dynamicClusterSize, open port from 8002 to 8001+dynamicClusterSize for managed machines.
        while [ $maxManagedIndex -le $maxDynamicClusterSize ]
        do
          managedPort=$(($wlsManagedPort + $maxManagedIndex))
          sudo firewall-cmd --zone=public --add-port=$managedPort/tcp
          maxManagedIndex=$(($maxManagedIndex + 1))
        done

        # open ports for coherence
        sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/tcp
        sudo firewall-cmd --zone=public --add-port=$coherenceListenPort/udp
        sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/tcp
        sudo firewall-cmd --zone=public --add-port=$coherenceLocalport-$coherenceLocalportAdjust/udp
        sudo firewall-cmd --zone=public --add-port=7/tcp
        
        sudo firewall-cmd --zone=public --add-port=$nmPort/tcp
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
  echo "//${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred ,dir_mode=0777,file_mode=0777,serverino"
  sudo bash -c "echo \"//${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred ,dir_mode=0777,file_mode=0777,serverino\" >> /etc/fstab"
  echo "mount -t cifs //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino"
  sudo mount -t cifs //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
  if [[ $? != 0 ]];
  then
         echo "Failed to mount //${storageAccountName}.file.core.windows.net/wlsshare $mountpointPath"
	 exit 1
  fi
}

# Copy SerializedSystemIni.dat file from admin server vm to share point
function copySerializedSystemIniFileToShare()
{
  runuser -l oracle -c "cp ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat ${mountpointPath}/."
  ls -lt ${mountpointPath}/SerializedSystemIni.dat
  if [[ $? != 0 ]]; 
  then
      echo "Failed to copy ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat"
      exit 1
  fi
}

# Get SerializedSystemIni.dat file from share point to managed server vm
function getSerializedSystemIniFileFromShare()
{
  runuser -l oracle -c "mv ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat.backup"
  runuser -l oracle -c "cp ${mountpointPath}/SerializedSystemIni.dat ${DOMAIN_PATH}/${wlsDomainName}/security/."
  ls -lt ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat
  if [[ $? != 0 ]]; 
  then
      echo "Failed to get ${mountpointPath}/SerializedSystemIni.dat"
      exit 1
  fi
  runuser -l oracle -c "chmod 640 ${DOMAIN_PATH}/${wlsDomainName}/security/SerializedSystemIni.dat"
}

# Create custom stopWebLogic script and add it to wls_admin service
# This script is created as stopWebLogic.sh will not work if non ssl admin listening port 7001 is disabled
# Refer https://github.com/wls-eng/arm-oraclelinux-wls/issues/164 
function createStopWebLogicScript()
{

cat <<EOF >${stopWebLogicScript}
#!/bin/sh
# This is custom script for stopping weblogic server using ADMIN_URL supplied
export ADMIN_URL="t3://${wlsAdminURL}"
${DOMAIN_PATH}/${wlsDomainName}/bin/stopWebLogic.sh
EOF

sudo chown -R $username:$groupname ${stopWebLogicScript}
sudo chmod -R 750 ${stopWebLogicScript}

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

   #validate Trust keystore
   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $customTrustKeyStoreFileName -storepass $customTrustKeyStorePassPhrase -storetype $customTrustKeyStoreType | grep 'Entry type:' | grep 'trustedCertEntry'"

   if [[ $? != 0 ]]; then
       echo "Error : Trust Keystore Validation Failed !!"
       exit 1
   fi

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
        customIdentityKeyStoreType=$(echo "$customIdentityKeyStoreType" | base64 --decode)

        customTrustKeyStoreData=$(echo "$customTrustKeyStoreData" | base64 --decode)
        customTrustKeyStorePassPhrase=$(echo "$customTrustKeyStorePassPhrase" | base64 --decode)
        customTrustKeyStoreType=$(echo "$customTrustKeyStoreType" | base64 --decode)

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


#main script starts here

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

# store arguments in a special array 
#args=("$@") 
# get number of elements 
#ELEMENTS=${#args[@]} 
 
# echo each element in array  
# for loop 
#for (( i=0;i<$ELEMENTS;i++)); do 
#    echo "ARG[${args[${i}]}]"
#done

read wlsDomainName wlsUserName wlsPassword managedServerPrefix indexValue vmNamePrefix maxDynamicClusterSize dynamicClusterSize adminVMName oracleHome storageAccountName storageAccountKey mountpointPath isHTTPAdminListenPortEnabled isCustomSSLEnabled customIdentityKeyStoreData customIdentityKeyStorePassPhrase customIdentityKeyStoreType customTrustKeyStoreData customTrustKeyStorePassPhrase customTrustKeyStoreType serverPrivateKeyAlias serverPrivateKeyPassPhrase

DOMAIN_PATH="/u01/domains"
startWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/startWebLogic.sh"
stopWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/bin/customStopWebLogic.sh"

isHTTPAdminListenPortEnabled="${isHTTPAdminListenPortEnabled,,}"

isCustomSSLEnabled="${isCustomSSLEnabled,,}"

# Always index 0 is set as admin server
coherenceListenPort=7574
coherenceLocalport=42000
coherenceLocalportAdjust=42200
wlsAdminPort=7001
wlsSSLAdminPort=7002
wlsAdminT3ChannelPort=7005
wlsManagedPort=8001

wlsAdminURL="$adminVMName:$wlsAdminT3ChannelPort"
SERVER_START_URL="http://$wlsAdminURL"
KEYSTORE_PATH="${DOMAIN_PATH}/${wlsDomainName}/keystores"

if [ "${isCustomSSLEnabled}" == "true" ];
then
   SERVER_START_URL="https://$adminVMName:$wlsSSLAdminPort"
fi

CHECK_URL="http://$wlsAdminURL/weblogic/ready"
adminWlstURL="t3://$wlsAdminURL"

wlsClusterName="cluster1"
dynamicServerTemplate="myServerTemplate"
nmHost=`hostname`
nmPort=5556
machineNamePrefix="machine"
machineName="$machineNamePrefix-$nmHost"
WEBLOGIC_DEPLOY_TOOL=https://github.com/oracle/weblogic-deploy-tooling/releases/download/weblogic-deploy-tooling-1.8.1/weblogic-deploy.zip
username="oracle"
groupname="oracle"

validateInput

if [ $indexValue == 0 ];
then
   wlsServerName="admin"
else
   serverIndex=$indexValue
   wlsServerName="$managedServerPrefix$serverIndex"
fi

SCRIPT_PWD=`pwd`
cleanup

installUtilities
mountFileShare

if [ $wlsServerName == "admin" ];
then
  updateNetworkRules "admin"
  create_adminSetup
  createStopWebLogicScript
  admin_boot_setup
  create_adminserver_service
  create_nodemanager_service
  enableAndStartAdminServerService
  enabledAndStartNodeManagerService
  wait_for_admin  
else
  updateNetworkRules "managed"
  create_managedSetup
  create_nodemanager_service
  enabledAndStartNodeManagerService
  start_cluster  
fi
cleanup
