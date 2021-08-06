#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Function to output message to StdErr
function echo_stderr()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./aadIntegration.sh"
}

function validateInput()
{
    if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]
    then
        echo_stderr "wlsUserName or wlsPassword is required. "
        exit 1
    fi

    if [ -z "$wlsDomainName" ];
    then
        echo_stderr "wlsDomainName is required. "
    fi

    if [ -z "$adProviderName" ];
    then
        echo_stderr "adProviderName is required. "
    fi

    if [ -z "$adPrincipal" ];
    then
        echo_stderr "adPrincipal is required. "
    fi

    if [ -z "$adPassword" ];
    then
        echo_stderr "adPassword is required. "
    fi

    if [ -z "$adServerHost" ];
    then
        echo_stderr "adServerHost is required. "
    fi

    if [ -z "$adServerPort" ];
    then
        echo_stderr "adServerPort is required. "
    fi

    if [ -z "$adGroupBaseDN" ];
    then
        echo_stderr "adGroupBaseDN is required. "
    fi

    if [ -z "$adUserBaseDN" ];
    then
        echo_stderr "adUserBaseDN is required. "
    fi

    if [ -z "$oracleHome" ];
    then
        echo_stderr "oracleHome is required. "
    fi

    if [ -z "$wlsAdminHost" ];
    then
        echo_stderr "wlsAdminHost is required. "
    fi

    if [ -z "$wlsAdminPort" ];
    then
        echo_stderr "wlsAdminPort is required. "
    fi

    if [ -z "$wlsADSSLCer" ];
    then
        echo_stderr "wlsADSSLCer is required. "
    fi

    if [ -z "$wlsLDAPPublicIP" ];
    then
        echo_stderr "wlsLDAPPublicIP is required. "
    fi

    if [ -z "$wlsAdminServerName" ];
    then
        echo_stderr "wlsAdminServerName is required. "
    fi

    if [ -z "$wlsDomainPath" ];
    then
        echo_stderr "wlsDomainPath is required. "
    fi

    if [ -z "$vmIndex" ];
    then
        echo_stderr "vmIndex is required. "
    fi


    if [ "${isCustomSSLEnabled,,}" != "true" ];
    then
        echo_stderr "Custom SSL value is not provided. Defaulting to false"
        isCustomSSLEnabled="false"
    else
        if   [ -z "$customTrustKeyStorePassPhrase" ];
        then
            echo "customTrustKeyStorePassPhrase is required "
            exit 1
        fi
    fi
}

function createAADProvider_model()
{
    cat <<EOF >${SCRIPT_PATH}/configure-active-directory.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
try:
   edit("$wlsAdminServerName")
   startEdit()
   cd('/')
   # Configure DefaultAuthenticator.
   cd('/SecurityConfiguration/' + '${wlsDomainName}' + '/Realms/myrealm/AuthenticationProviders/DefaultAuthenticator')
   cmo.setControlFlag('SUFFICIENT')

   # Configure Active Directory.
   cd('/SecurityConfiguration/' + '${wlsDomainName}' + '/Realms/myrealm')
   cmo.createAuthenticationProvider('${adProviderName}', 'weblogic.security.providers.authentication.ActiveDirectoryAuthenticator')

   cd('/SecurityConfiguration/' + '${wlsDomainName}' + '/Realms/myrealm/AuthenticationProviders/' + '${adProviderName}')
   cmo.setControlFlag('OPTIONAL')

   cd('/SecurityConfiguration/' + '${wlsDomainName}' + '/Realms/myrealm')
   set('AuthenticationProviders',jarray.array([ObjectName('Security:Name=myrealm' + '${adProviderName}'), 
      ObjectName('Security:Name=myrealmDefaultAuthenticator'), 
      ObjectName('Security:Name=myrealmDefaultIdentityAsserter')], ObjectName))


   cd('/SecurityConfiguration/' + '${wlsDomainName}' + '/Realms/myrealm/AuthenticationProviders/' + '${adProviderName}')
   cmo.setControlFlag('SUFFICIENT')
   cmo.setUserNameAttribute('${LDAP_USER_NAME}')
   cmo.setUserFromNameFilter('${LDAP_USER_FROM_NAME_FILTER}')
   cmo.setPrincipal('${adPrincipal}')
   cmo.setHost('${adServerHost}')
   set('Credential', '${adPassword}')
   cmo.setGroupBaseDN('${adGroupBaseDN}')
   cmo.setUserBaseDN('${adUserBaseDN}')
   cmo.setPort(int('${adServerPort}'))
   cmo.setSSLEnabled(true)

   # for performance tuning
   cmo.setMaxGroupMembershipSearchLevel(1)
   cmo.setGroupMembershipSearching('limited')
   cmo.setUseTokenGroupsForGroupMembershipLookup(true)
   cmo.setResultsTimeLimit(300)
   cmo.setConnectionRetryLimit(5)
   cmo.setConnectTimeout(120)
   cmo.setCacheTTL(300)
   cmo.setConnectionPoolSize(60)
   cmo.setCacheSize(4000)
   cmo.setGroupHierarchyCacheTTL(300)
   cmo.setEnableSIDtoGroupLookupCaching(true)

   save()
   resolve()
   activate()
except:
   stopEdit('y')
   sys.exit(1)

destroyEditSession("$wlsAdminServerName",force = true)
disconnect()
sys.exit(0)
EOF
}

function createSSL_model()
{
    cat <<EOF >${SCRIPT_PATH}/configure-ssl.py
# Connect to the AdminServer.
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
shutdown('$WLS_CLUSTER_NAME', 'Cluster')
print "Ignore host name verification in admin server."
try:
    edit('$wlsAdminServerName')
    startEdit()
    cd('/Servers/${wlsAdminServerName}/SSL/${wlsAdminServerName}')
    cmo.setHostnameVerificationIgnored(true)
    print "Ignore host name verification in cluster."

    cd('/ServerTemplates/${WLS_DYNAMIC_SERVER_TEMPLATE}/SSL/${WLS_DYNAMIC_SERVER_TEMPLATE}')
    cmo.setHostnameVerificationIgnored(true)
EOF

    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    ${JAVA_HOME}/bin/java -version  2>&1  | grep -e "1[.]8[.][0-9]*_"  > /dev/null 
    javaStatus=$?
    if [ "${javaStatus}" == "0" ]; then
        cat <<EOF >>${SCRIPT_PATH}/configure-ssl.py
    cd('/ServerTemplates/${WLS_DYNAMIC_SERVER_TEMPLATE}//ServerStart/${WLS_DYNAMIC_SERVER_TEMPLATE}')
    arguments = cmo.getArguments()
    if(str(arguments) == 'None'):
        arguments = '${JAVA_OPTIONS_TLS_V12}'
    else:
        arguments = str(arguments) + ' ' + '${JAVA_OPTIONS_TLS_V12}'
    cmo.setArguments(arguments)
EOF
    fi

cat <<EOF >>${SCRIPT_PATH}/configure-ssl.py
    save()
    resolve()
    activate()
except:
    stopEdit('y')
    dumpStack()
    sys.exit(1)
destroyEditSession("$wlsAdminServerName")

try: 
    start('$WLS_CLUSTER_NAME', 'Cluster')
except:
    dumpStack()

disconnect()
EOF
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
        cer_begin=$((cer_begin+64))
    done

    openssl base64 -d -in ${SCRIPT_PWD}/security/AzureADLDAPCerBase64String.txt -out ${SCRIPT_PWD}/security/AzureADTrust.cer
    addsCertificate=${SCRIPT_PWD}/security/AzureADTrust.cer
}

function importAADCertificate()
{
    # import the key to java security 
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    # For AAD failure: exception happens when importing certificate to JDK 11.0.7
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
    if [ -n "$queryAADTrust" ];
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
        sudo ${JAVA_HOME}/bin/keytool -list -v -keystore ${DOMAIN_PATH}/${wlsDomainName}/keystores/trust.keystore -storepass ${customTrustKeyStorePassPhrase} -storetype ${customTrustKeyStoreType} | grep 'Entry type:' | grep 'trustedCertEntry'

        if [[ $? != 0 ]]; then
           echo "Error : Trust Keystore Validation Failed !!"
           exit 1
        fi

        # For SSL enabled causes AAD failure #225
        # ISSUE: https://github.com/wls-eng/arm-oraclelinux-wls/issues/225

        echo "Importing AAD Certificate into WLS Custom Trust Key Store: "

        sudo ${JAVA_HOME}/bin/keytool -noprompt -import -trustcacerts -keystore ${DOMAIN_PATH}/${wlsDomainName}/keystores/trust.keystore -storepass ${customTrustKeyStorePassPhrase} -alias aadtrust -file ${addsCertificate} -storetype ${customTrustKeyStoreType}
    else
        echo "customSSL not enabled. Not required to configure AAD for WebLogic Custom SSL"
    fi
}

function configureSSL()
{
    echo "configure ladp ssl"
    sudo chown -R ${USER_ORACLE}:${GROUP_ORACLE} ${SCRIPT_PATH}
    runuser -l ${USER_ORACLE} -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${SCRIPT_PATH}/configure-ssl.py" 

    errorCode=$?
    if [ $errorCode -eq 1 ]
    then 
        echo "Exception occurs during SSL configuration, please check."
        exit 1
    fi
}

function configureAzureActiveDirectory()
{
    echo "create Azure Active Directory provider"
    sudo chown -R ${USER_ORACLE}:${GROUP_ORACLE} ${SCRIPT_PATH}
    runuser -l ${USER_ORACLE} -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${SCRIPT_PATH}/configure-active-directory.py"

    errorCode=$?
    if [ $errorCode -eq 1 ]
    then 
        echo "Exception occurs during Azure Active Directory configuration, please check."
        exit 1
    fi
}

function restartAdminServerService()
{
     echo "Restart weblogic admin server service"
     sudo systemctl stop wls_admin
     sudo systemctl start wls_admin
}

#This function to check admin server status 
function wait_for_admin()
{
    #check admin server status
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
    echo "Check admin server status"
    while [[ "$status" != "200" ]]
    do
    echo "."
    count=$((count+1))
    if [ $count -le 30 ];
    then
        sleep 1m
    else
        echo "Error : Maximum attempts exceeded while checking admin server status"
        exit 1
    fi
    status=`curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'}`
    if [ "$status" == "200" ];
    then
        echo "WebLogic Server is running..."
        break
    fi
    done  
}

function cleanup()
{
    echo "Cleaning up temporary files..."
    rm -f -r ${SCRIPT_PATH}
    rm -rf ${SCRIPT_PWD}/security/*
    echo "Cleanup completed."
}

function enableTLSv12onJDK8()
{
    if ! grep -q "${STRING_ENABLE_TLSV12}" ${wlsDomainPath}/bin/setDomainEnv.sh; then
        cat <<EOF >>${wlsDomainPath}/bin/setDomainEnv.sh
# Append -Djdk.tls.client.protocols to JAVA_OPTIONS in jdk8
# Enable TLSv1.2
\${JAVA_HOME}/bin/java -version  2>&1  | grep -e "1[.]8[.][0-9]*_"  > /dev/null 
javaStatus=$?

if [[ "\${javaStatus}" = "0" && "\${JAVA_OPTIONS}"  != *"${JAVA_OPTIONS_TLS_V12}"* ]]; then
    JAVA_OPTIONS="\${JAVA_OPTIONS} ${JAVA_OPTIONS_TLS_V12}"
    export JAVA_OPTIONS
fi
EOF
fi
}

function restartCluster()
{
    cat <<EOF >${SCRIPT_PWD}/restart-cluster.py
# Connect to the AdminServer.
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
print "Restart cluster."
try: 
    print "Shutdown cluster."
    shutdown('$WLS_CLUSTER_NAME', 'Cluster')
    print "Start cluster."
    start('$WLS_CLUSTER_NAME', 'Cluster')
except:
    dumpStack()

disconnect()
EOF

    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    java $WLST_ARGS weblogic.WLST ${SCRIPT_PWD}/restart-cluster.py
    errorCode=$?
    if [ $errorCode -eq 1 ]
    then 
        echo "Failed to restart cluster."
        exit 1
    fi
}

function createTempFolder()
{
    SCRIPT_PATH="/u01/tmp"
    sudo rm -f -r ${SCRIPT_PATH}
    sudo mkdir ${SCRIPT_PATH}
    sudo rm -rf $SCRIPT_PATH/*
}

LDAP_USER_NAME='sAMAccountName'
LDAP_USER_FROM_NAME_FILTER='(&(sAMAccountName=%u)(objectclass=user))'
JAVA_OPTIONS_TLS_V12="-Djdk.tls.client.protocols=TLSv1.2"
STRING_ENABLE_TLSV12="Append -Djdk.tls.client.protocols to JAVA_OPTIONS in jdk8"
WLS_CLUSTER_NAME="cluster1"
WLS_DYNAMIC_SERVER_TEMPLATE="myServerTemplate"
SCRIPT_PWD=`pwd`
USER_ORACLE="oracle"
GROUP_ORACLE="oracle"
DOMAIN_PATH="/u01/domains"

read wlsUserName wlsPassword wlsDomainName adProviderName adServerHost adServerPort adPrincipal adPassword adGroupBaseDN adUserBaseDN oracleHome wlsAdminHost wlsAdminPort wlsADSSLCer wlsLDAPPublicIP wlsAdminServerName wlsDomainPath isCustomSSLEnabled customTrustKeyStorePassPhrase customTrustKeyStoreType vmIndex

isCustomSSLEnabled="${isCustomSSLEnabled,,}"

if [ "${isCustomSSLEnabled,,}" == "true" ];
then
    customTrustKeyStorePassPhrase=$(echo "$customTrustKeyStorePassPhrase" | base64 --decode)
    customTrustKeyStoreType=$(echo "$customTrustKeyStoreType" | base64 --decode)
fi

wlsAdminURL=$wlsAdminHost:$wlsAdminPort

if [ $vmIndex -eq 0 ];
then
    createTempFolder
    echo "check status of admin server"
    wait_for_admin

    echo "start to configure Azure Active Directory"
    enableTLSv12onJDK8
    createAADProvider_model
    createSSL_model
    mapLDAPHostWithPublicIP
    parseLDAPCertificate
    importAADCertificate
    importAADCertificateIntoWLSCustomTrustKeyStore
    configureSSL
    configureAzureActiveDirectory
    restartAdminServerService

    echo "Waiting for admin server to be available"
    wait_for_admin
    echo "Weblogic admin server is up and running"
    restartCluster
    cleanup
else
    createTempFolder
    mapLDAPHostWithPublicIP
    parseLDAPCertificate
    importAADCertificate
    importAADCertificateIntoWLSCustomTrustKeyStore
    cleanup
fi

