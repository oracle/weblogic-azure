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
    rm -rf $DOMAIN_PATH/*.py
    rm -rf ${CUSTOM_HOSTNAME_VERIFIER_HOME}
 
    echo "Cleanup completed."
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
        echo_stderr "Error : Invalid minimum validity days supplied"
  		exit 1
  	fi 

	# Check whether KEYSTORE supplied can be opened for reading
	# Redirecting as no need to display the contents
	runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE > /dev/null 2>&1"
	if [ $? != 0 ];
	then
		echo_stderr "Error opening the keystore : $KEYSTORE"
		exit 1
	fi

	aliasList=`runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; keytool -list -v -keystore $KEYSTORE  -storepass $PASSWORD -storetype $KEY_STORE_TYPE | grep Alias" |awk '{print $3}'`
	if [[ -z $aliasList ]]; 
	then 
		echo_stderr "Error : No alias found in supplied certificate $KEYSTORE"
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
			echo_stderr "$KEYSTORE is \"$VALIDITY_PERIOD\""
			echo_stderr "Error : Supplied certificate $KEYSTORE is either expired or expiring soon within $MIN_CERT_VALIDITY day"
			exit 1
		fi		
	done
	echo "$KEYSTORE validation is successful"
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
            ServerStart:
               Arguments: '${SERVER_STARTUP_ARGS}'
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
            ServerStart:
               Arguments: '${SERVER_STARTUP_ARGS}'
            WebServer:
               FrontendHost: '${adminPublicHostName}'
               FrontendHTTPSPort: $wlsSSLAdminPort
               FrontendHTTPPort: $wlsAdminPort
EOF
  fi

#check if remoteanonymous attributes are supported in current WLS version
#if supported, disable them by setting the attributes to false

hasRemoteAnonymousAttribs="$(containsRemoteAnonymousT3RMIIAttribs)"
echo "hasRemoteAnonymousAttribs: ${hasRemoteAnonymousAttribs}"

if [ "${hasRemoteAnonymousAttribs}" == "true" ];
then
echo "adding settings to disable remote anonymous t3/rmi disabled under domain security configuration"
cat <<EOF>>$DOMAIN_PATH/admin-domain.yaml
   SecurityConfiguration:
       RemoteAnonymousRmiiiopEnabled: false
       RemoteAnonymousRmit3Enabled: false
EOF
fi

}

#Function to create Admin Only Domain
function create_adminDomain()
{
    echo "Creating Admin Only Domain"
    echo "Creating domain path $DOMAIN_PATH"
    sudo mkdir -p $DOMAIN_PATH

    # WebLogic base images are already having weblogic-deploy, hence no need to download   
    if [ ! -d "$DOMAIN_PATH/weblogic-deploy" ];
    then
        echo "Deployment tool not found in the path $DOMAIN_PATH"
        exit 1
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
WorkingDirectory=/u01/domains/$wlsDomainName
Environment="JAVA_OPTIONS=${SERVER_STARTUP_ARGS}"
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

    if [ -z "$virtualNetworkNewOrExisting" ];
    then
        echo_stderr "virtualNetworkNewOrExisting is required. "
        exit 1
    fi

    if [ -z "$storageAccountPrivateIp" ];
    then
        echo_stderr "storageAccountPrivateIp is required. "
        exit 1
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
  echo "//${storageAccountPrivateIp}/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino"
  sudo bash -c "echo \"//${storageAccountPrivateIp}/wlsshare $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino\" >> /etc/fstab"
  echo "mount -t cifs //${storageAccountPrivateIp}/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino"
  sudo mount -t cifs //${storageAccountPrivateIp}/wlsshare $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
  if [[ $? != 0 ]];
  then
         echo "Failed to mount //${storageAccountPrivateIp}/wlsshare $mountpointPath"
	 exit 1
  fi
}

#this function set the umask 027 (chmod 740) as required by WebLogic security checks
function setUMaskForSecurityDir()
{
   echo "setting umask 027 (chmod 740) for domain/admin security directory"

   if [ -f "$DOMAIN_PATH/$wlsDomainName/servers/$wlsServerName/security/boot.properties" ];
   then
      runuser -l oracle -c "chmod 740 $DOMAIN_PATH/$wlsDomainName/servers/$wlsServerName/security/boot.properties"
   fi

   if [ -d "$DOMAIN_PATH/$wlsDomainName/servers/$wlsServerName/security" ];
   then
       runuser -l oracle -c "chmod 740 $DOMAIN_PATH/$wlsDomainName/servers/$wlsServerName/security"
   fi

}

#this function checks if remote Anonymous T3/RMI Attributes are available as part of domain security configuration
function containsRemoteAnonymousT3RMIIAttribs()
{
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/modelHelp.sh -oracle_home $oracleHome topology:/SecurityConfiguration | grep RemoteAnonymousRmiiiopEnabled" >> /dev/null

    result1=$?

    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; $DOMAIN_PATH/weblogic-deploy/bin/modelHelp.sh -oracle_home $oracleHome topology:/SecurityConfiguration | grep RemoteAnonymousRmit3Enabled" >> /dev/null

    result2=$?

    if [ $result1 == 0 ] && [ $result2 == 0 ]; then
      echo "true"
    else
      echo "false"
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

   runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; ${CUSTOM_HOSTNAME_VERIFIER_HOME}/generateCustomHostNameVerifier.sh ${wlsAdminHost} ${adminPublicHostName} ${adminPublicHostName} ${dnsLabelPrefix} ${wlsDomainName} ${location}"
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

#main script starts here


SCRIPT_PWD=`pwd`
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

# Used for certificate expiry validation
CURRENT_DATE=`date +%s`
# Supplied certificate to have minimum days validity for the deployment
MIN_CERT_VALIDITY="1"


#read arguments from stdin
read wlsDomainName wlsUserName wlsPassword wlsAdminHost oracleHome storageAccountName storageAccountKey mountpointPath isHTTPAdminListenPortEnabled adminPublicHostName dnsLabelPrefix location virtualNetworkNewOrExisting storageAccountPrivateIp isCustomSSLEnabled customIdentityKeyStoreData customIdentityKeyStorePassPhrase customIdentityKeyStoreType customTrustKeyStoreData customTrustKeyStorePassPhrase customTrustKeyStoreType serverPrivateKeyAlias serverPrivateKeyPassPhrase

wlsServerName="admin"
DOMAIN_PATH="/u01/domains"
CUSTOM_HOSTNAME_VERIFIER_HOME="/u01/app/custom-hostname-verifier"
startWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/startWebLogic.sh"
stopWebLogicScript="${DOMAIN_PATH}/${wlsDomainName}/bin/customStopWebLogic.sh"

validateInput

installUtilities

mountFileShare

SERVER_STARTUP_ARGS="-Dlog4j2.formatMsgNoLookups=true"
KEYSTORE_PATH="${DOMAIN_PATH}/${wlsDomainName}/keystores"
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

create_adminDomain

createStopWebLogicScript

cleanup

updateNetworkRules

create_adminserver_service

admin_boot_setup

generateCustomHostNameVerifier

copyCustomHostNameVerifierJarsToWebLogicClasspath

setUMaskForSecurityDir

enableAndStartAdminServerService

echo "Waiting for admin server to be available"
wait_for_admin
echo "Weblogic admin server is up and running"

configureCustomHostNameVerifier

cleanup
