#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Description
#  This script configures ELK (Elasticsearch, Logstash and Kibana) Stack on WebLogic Server Domain.

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./setupAdminDomain.sh <<< \"<wlsDomainSetupArgsFromStdIn>\""
}

function setupKeyStoreDir()
{
    sudo mkdir -p $KEYSTORE_PATH
    sudo rm -rf $KEYSTORE_PATH/*
}

function installUtilities()
{
    echo "Installing zip unzip wget vnc-server rng-tools bind-utils"
    sudo yum install -y zip unzip wget vnc-server rng-tools bind-utils

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

function downloadUsingWget()
{
   downloadURL=$1
   filename=${downloadURL##*/}
   for in in {1..5}
   do
     wget $downloadURL
     if [ $? != 0 ];
     then
        echo "$filename Driver Download failed on $downloadURL. Trying again..."
	rm -f $filename
     else 
        echo "$filename Driver Downloaded successfully"
        break
     fi
   done
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."

    rm -rf $DOMAIN_PATH/admin-domain.yaml
    rm -rf $DOMAIN_PATH/weblogic-deploy.zip
    rm -rf $DOMAIN_PATH/weblogic-deploy
    rm -rf $DOMAIN_PATH/deploy-app.yaml
    rm -rf $DOMAIN_PATH/shoppingcart.zip
 
    echo "Cleanup completed."
}

#Creates weblogic deployment model for admin domain
function create_admin_model()
{
    echo "Creating admin domain model"
    cat /dev/null > $DOMAIN_PATH/admin-domain.yaml

    if [ "${isCustomSSLEnabled,,}" == "true" ];
    then
        cat <<EOF >$DOMAIN_PATH/admin-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   AdminServerName: admin
EOF

        cat <<EOF >>$DOMAIN_PATH/admin-domain.yaml
   Server:
        'admin':
            ListenPort: $wlsAdminPort
            NetworkAccessPoint:
                'adminT3Channel':
                    ListenAddress: '$wlsAdminHost'
                    ListenPort: $wlsAdminT3ChannelPort
                    Protocol: t3
                    Enabled: true
            ListenPortEnabled: $isHTTPAdminListenPortEnabled
            RestartDelaySeconds: 10
            KeyStores: 'CustomIdentityAndCustomTrust'
            CustomIdentityKeyStoreFileName: "$customIdentityKeyStoreFileName"
            CustomIdentityKeyStoreType: "$customIdentityKeyStoreType"
            CustomIdentityKeyStorePassPhraseEncrypted: "$customIdentityKeyStorePassPhrase"
            CustomTrustKeyStoreFileName: "$customTrustKeyStoreFileName"
            CustomTrustKeyStoreType: "$customTrustKeyStoreType"
            CustomTrustKeyStorePassPhraseEncrypted: "$customTrustKeyStorePassPhrase"
            SSL:
               ServerPrivateKeyAlias: "$serverPrivateKeyAlias"
               ServerPrivateKeyPassPhraseEncrypted: "$serverPrivateKeyPassPhrase"
               ListenPort: $wlsSSLAdminPort
               Enabled: true
            WebServer:
                FrontendHost: '${adminPublicHostName}'
                FrontendHTTPSPort: $wlsSSLAdminPort
                FrontendHTTPPort: $wlsAdminPort
EOF
    else
        cat <<EOF >>$DOMAIN_PATH/admin-domain.yaml
domainInfo:
   AdminUserName: "$wlsUserName"
   AdminPassword: "$wlsPassword"
   ServerStartMode: prod
topology:
   Name: "$wlsDomainName"
   AdminServerName: admin
   Server:
        'admin':
            NetworkAccessPoint:
                'adminT3Channel':
                    ListenAddress: '$wlsAdminHost'
                    ListenPort: $wlsAdminT3ChannelPort
                    Protocol: t3
                    Enabled: true
            ListenPort: $wlsAdminPort
            ListenPortEnabled: $isHTTPAdminListenPortEnabled
            RestartDelaySeconds: 10
            SSL:
               ListenPort: $wlsSSLAdminPort
               Enabled: true
            WebServer:
                FrontendHost: '${adminPublicHostName}'
                FrontendHTTPSPort: $wlsSSLAdminPort
                FrontendHTTPPort: $wlsAdminPort
EOF
  fi
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
          SourcePath: $DOMAIN_PATH/shoppingcart.war
          Target: admin
          ModuleType: war
EOF
}

#Function to create Admin Only Domain
function create_adminDomain()
{
    echo "Creating Admin Only Domain"
    echo "Creating domain path /u01/domains"
    echo "Downloading weblogic-deploy-tool"

    DOMAIN_PATH="/u01/domains"
    sudo mkdir -p $DOMAIN_PATH
    sudo rm -rf $DOMAIN_PATH/*

    if [ ! -d "$DOMAIN_PATH/weblogic-deploy" ];
    then
        echo "Deployment tool not found. Downloading..."
    cd $DOMAIN_PATH
    wget -q $WEBLOGIC_DEPLOY_TOOL  
    if [[ $? != 0 ]]; then
       echo "Error : Downloading weblogic-deploy-tool failed"
       exit 1
    fi
    sudo unzip -o weblogic-deploy.zip -d $DOMAIN_PATH
    else
        echo "Deploy tool already available at $DOMAIN_PATH/weblogic-deploy"
    fi

    storeCustomSSLCerts

    create_admin_model
    sudo chown -R $username:$groupname $DOMAIN_PATH
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/createDomain.sh -oracle_home $oracleHome -domain_parent $DOMAIN_PATH  -domain_type WLS -model_file $DOMAIN_PATH/admin-domain.yaml"
    if [[ $? != 0 ]]; then
       echo "Error : Domain creation failed"
       exit 1
    fi
}

# Boot properties for admin server
function admin_boot_setup()
{
echo "Creating admin server boot properties"
 #Create the boot.properties directory
 mkdir -p "$DOMAIN_PATH/$wlsDomainName/servers/admin/security"
 echo "username=$wlsUserName" > "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 echo "password=$wlsPassword" >> "$DOMAIN_PATH/$wlsDomainName/servers/admin/security/boot.properties"
 sudo chown -R $username:$groupname $DOMAIN_PATH/$wlsDomainName/servers
 echo "Completed admin server boot properties"
}

# Create adminserver as service
function create_adminserver_service()
{
echo "Creating weblogic admin server service"
cat <<EOF >/etc/systemd/system/wls_admin.service
[Unit]
Description=WebLogic Adminserver service
After=network-online.target
Wants=network-online.target
 
[Service]
Type=simple
WorkingDirectory="/u01/domains/$wlsDomainName"
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
echo "Completed weblogic admin server service"
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

#Function to deploy application in offline mode
#Sample shopping cart 
function deploy_sampleApp()
{
    create_app_deploy_model
	echo "Downloading and Deploying Sample Application"
	wget -q $samplApp
	sudo unzip -o shoppingcart.zip -d $DOMAIN_PATH
    sudo chown -R $username:$groupname $DOMAIN_PATH/shoppingcart.*
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/deployApps.sh -oracle_home $oracleHome -archive_file $DOMAIN_PATH/shoppingcart.war -domain_home $DOMAIN_PATH/$wlsDomainName -model_file  $DOMAIN_PATH/deploy-app.yaml"
	if [[ $? != 0 ]]; then
       echo "Error : Deploying application failed"
       exit 1
    fi
}

function validateInput()
{
    if [ -z "$wlsDomainName" ];
    then
        echo_stderr "wlsDomainName is required. "
        exit 1
    fi

    if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]
    then
        echo_stderr "wlsUserName or wlsPassword is required. "
        exit 1
    fi

    if [ -z "$wlsAdminHost" ];
    then
        echo_stderr "wlsAdminHost is required. "
        exit 1
    fi

    if [ -z "$oracleHome" ];
    then
        echo_stderr "oracleHome is required. "
        exit 1
    fi

    if [ -z "$storageAccountName" ] || [ -z "${storageAccountKey}" ] || [  -z ${mountpointPath} ]
    then
        echo_stderr "storageAccountName, storageAccountKey and mountpointPath is required. "
        exit 1
    fi

    if [ -z "$isHTTPAdminListenPortEnabled" ];
    then
        echo_stderr "isHTTPAdminListenPortEnabled is required. "
        exit 1
    fi

    if [ -z "$adminPublicHostName" ];
    then
        echo_stderr "adminPublicHostName is required. "
        exit 1
    fi

    if [ "${isCustomSSLEnabled,,}" != "true" ];
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

function enableAndStartAdminServerService()
{
    echo "Starting weblogic admin server as service"
    sudo systemctl enable wls_admin
    sudo systemctl daemon-reload
    sudo systemctl start wls_admin
}

function updateNetworkRules()
{
    # for Oracle Linux 7.3, 7.4, iptable is not running.
    if [ -z `command -v firewall-cmd` ]; then
        return 0
    fi
    
    # for Oracle Linux 7.6, open weblogic ports
    echo "update network rules for admin server"
    sudo firewall-cmd --zone=public --add-port=$wlsAdminPort/tcp
    sudo firewall-cmd --zone=public --add-port=$wlsSSLAdminPort/tcp
    sudo firewall-cmd --zone=public --add-port=$wlsAdminT3ChannelPort/tcp
    sudo firewall-cmd --runtime-to-permanent
    sudo systemctl restart firewalld
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
    if [ "${isCustomSSLEnabled,,}" == "true" ];
    then

        setupKeyStoreDir

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


#main script starts here

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

#read arguments from stdin
read wlsDomainName wlsUserName wlsPassword wlsAdminHost oracleHome storageAccountName storageAccountKey mountpointPath isHTTPAdminListenPortEnabled adminPublicHostName isCustomSSLEnabled customIdentityKeyStoreData customIdentityKeyStorePassPhrase customIdentityKeyStoreType customTrustKeyStoreData customTrustKeyStorePassPhrase customTrustKeyStoreType serverPrivateKeyAlias serverPrivateKeyPassPhrase

DOMAIN_PATH="/u01/domains"
startWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/startWebLogic.sh"
stopWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/bin/customStopWebLogic.sh"

validateInput

installUtilities

mountFileShare

KEYSTORE_PATH="${DOMAIN_PATH}/${wlsDomainName}/keystores"
WEBLOGIC_DEPLOY_TOOL=https://github.com/oracle/weblogic-deploy-tooling/releases/download/weblogic-deploy-tooling-1.8.1/weblogic-deploy.zip
samplApp="https://www.oracle.com/webfolder/technetwork/tutorials/obe/fmw/wls/10g/r3/cluster/session_state/files/shoppingcart.zip"
wlsAdminPort=7001
wlsSSLAdminPort=7002
wlsAdminT3ChannelPort=7005

if [ "${isHTTPAdminListenPortEnabled,,}" == "true" ];
then
    wlsAdminURL="$wlsAdminHost:$wlsAdminPort"
else
    wlsAdminURL="$wlsAdminHost:$wlsAdminT3ChannelPort"
fi

username="oracle"
groupname="oracle"

SCRIPT_PWD=`pwd`

create_adminDomain

createStopWebLogicScript

deploy_sampleApp

cleanup

updateNetworkRules

create_adminserver_service

admin_boot_setup

enableAndStartAdminServerService

echo "Waiting for admin server to be available"
wait_for_admin
echo "Weblogic admin server is up and running"
