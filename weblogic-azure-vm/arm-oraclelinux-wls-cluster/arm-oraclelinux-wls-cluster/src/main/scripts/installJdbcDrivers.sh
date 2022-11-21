# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This script is to install jdbc libraries at WebLogic cluster domain.

# /bin/bash

#Function to output message to StdErr
function echo_stderr() {
    echo "$@" >&2
}

#Function to display usage message
function usage() {
    echo_stderr "./installJdbcDrivers.sh <<< \"<dataSourceConfigArgumentsFromStdIn>\""
}

function validate_input() {

    # parse base64 string
    wlsPassword=$(echo "${wlsPassword}" | base64 -d)

    if [ -z "$oracleHome" ]; then
        echo _stderr "Please provide oracleHome"
        exit 1
    fi

    if [ -z "$domainPath" ]; then
        echo _stderr "Please provide domainPath"
        exit 1
    fi

    if [ -z "$wlsServerName" ]; then
        echo _stderr "Please provide wlsServerName"
        exit 1
    fi

    if [ -z "$wlsAdminHost" ]; then
        echo _stderr "Please provide wlsAdminHost"
        exit 1
    fi

    if [ -z "$wlsAdminPort" ]; then
        echo _stderr "Please provide wlsAdminPort"
        exit 1
    fi

    if [ -z "$wlsUserName" ]; then
        echo _stderr "Please provide wlsUserName"
        exit 1
    fi

    if [ -z "$wlsPassword" ]; then
        echo _stderr "Please provide wlsPassword"
        exit 1
    fi

    if [ -z "$databaseType" ]; then
        echo _stderr "Please provide databaseType"
        exit 1
    fi

    if [ -z "$enablePswlessConnection" ]; then
        echo _stderr "Please provide enablePswlessConnection"
        exit 1
    fi
}

function install_maven() {
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fksL "${url4MavenInstaller}" -o ${mvnInstaller}
    if [ $? != 0 ]; then
        echo_stderr "Failed to download ${url4MavenInstaller}."
    fi

    tar xzvf ${mvnInstaller} -C /u01/app
    export MAVEN_HOME=/u01/app/apache-maven-${mvnVersion}
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh # set JAVA_HOME
    export PATH=${MAVEN_HOME}/bin:$PATH

    rm ${mvnInstaller} -f
    mvn --version
    if [ $? != 0 ]; then
        echo_stderr "Failed to install maven."
    fi
}

function uninstall_maven() {
    sudo rm -f ${MAVEN_HOME} -R
}

function install_azure_mysql_libraries() {
    local mySQLPom=mysql-pom.xml
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fksL "${gitUrl4AzureMySQLJDBCPomFile}" -o ${mySQLPom}
    if [ $? != 0 ]; then
        echo_stderr "Failed to download ${gitUrl4AzureMySQLJDBCPomFile}."
    fi

    install_maven
    echo "download dependencies"
    mvn dependency:copy-dependencies -f ${mySQLPom}
    if [ $? -eq 0 ]; then
        ls -l target/dependency/

        domainBase=$(dirname $domainPath)
        sudo mkdir -p ${domainBase}/azure-libraries/identity
        sudo mkdir -p ${domainBase}/azure-libraries/jackson
        # fix JARs conflict issue, put jackson libraries to PRE_CLASSPATH to upgrade the existing libs.
        sudo mv target/dependency/jackson-annotations-*.jar ${domainBase}/azure-libraries/jackson
        sudo mv target/dependency/jackson-core-*.jar ${domainBase}/azure-libraries/jackson
        sudo mv target/dependency/jackson-databind-*.jar ${domainBase}/azure-libraries/jackson
        sudo mv target/dependency/jackson-dataformat-xml-*.jar ${domainBase}/azure-libraries/jackson
        # Thoes jars will be appended to CLASSPATH
        sudo mv target/dependency/*.jar ${domainBase}/azure-libraries/identity
        sudo chown -R oracle:oracle ${domainBase}/azure-libraries
    else
        echo "Failed to download dependencies for azure-identity-providers-jdbc-mysql"
        exit 1
    fi

    rm ${mySQLPom} -f
    uninstall_maven
    
    sed -i 's;^export DOMAIN_HOME;&\nCLASSPATH="'${domainBase}'/azure-libraries/identity/*:${CLASSPATH}";' ${domainPath}/bin/setDomainEnv.sh
    sed -i 's;^export DOMAIN_HOME;&\nPRE_CLASSPATH="'${domainBase}'/azure-libraries/jackson/*:${PRE_CLASSPATH}";' ${domainPath}/bin/setDomainEnv.sh
}

function upgrade_mysql_driver() {
    curl -m ${curlMaxTime} --retry ${retryMaxAttempt} -fksL "${wlsMySQLDriverUrl}" -o ${mysqlDriverJarName}
    if [ $? != 0 ]; then
        echo_stderr "Failed to download ${wlsMySQLDriverUrl}."
    fi

    local domainBase=$(dirname $domainPath)
    sudo mkdir ${domainBase}/external-libraries
    sudo mv ${mysqlDriverJarName} ${domainBase}/external-libraries/
    sudo chown -R oracle:oracle ${domainBase}/external-libraries

    sed -i 's;^export DOMAIN_HOME;&\nPRE_CLASSPATH="'${domainBase}'/external-libraries/'${mysqlDriverJarName}':${PRE_CLASSPATH}";' ${domainPath}/bin/setDomainEnv.sh
}

#This function to wait for admin server
function wait_for_admin() {
    #wait for admin to start
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
    echo "Waiting for admin server to start"
    while [[ "$status" != "200" ]]; do
        echo "."
        count=$((count + 1))
        if [ $count -le 30 ]; then
            sleep 1m
        else
            echo "Error : Maximum attempts exceeded while starting admin server"
            exit 1
        fi
        status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
        if [ "$status" == "200" ]; then
            echo "Admin Server started succesfully..."
            break
        fi
    done
}

function restart_admin_service() {
    echo "Restart weblogic admin server service"
    sudo systemctl stop wls_admin
    sudo systemctl start wls_admin
    wait_for_admin
}

function restart_managed_servers() {
    echo "Restart managed servers"
    cat <<EOF >${SCRIPT_PWD}/restart-managedServer.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
servers=cmo.getServers()
domainRuntime()
print "Restart the servers which are in RUNNING status"
for server in servers:
    bean="/ServerLifeCycleRuntimes/"+server.getName()
    serverbean=getMBean(bean)
    if (serverbean.getState() in ("RUNNING")) and (server.getName() == '${wlsServerName}'):
        try:
            print "Stop the Server ",server.getName()
            shutdown(server.getName(),server.getType(),ignoreSessions='true',force='true')
            print "Start the Server ",server.getName()
            start(server.getName(),server.getType())
            break
        except:
            print "Failed restarting managed server ", server.getName()
            dumpStack()
serverConfig()
disconnect()
EOF
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
    java $WLST_ARGS weblogic.WLST ${SCRIPT_PWD}/restart-managedServer.py

    if [[ $? != 0 ]]; then
        echo "Error : Fail to restart managed server to configuration external libraries."
        exit 1
    fi
}

#read arguments from stdin
read oracleHome domainPath wlsServerName wlsAdminHost wlsAdminPort wlsUserName wlsPassword databaseType enablePswlessConnection

export curlMaxTime=120 # seconds
export gitUrl4AzureMySQLJDBCPomFile="https://raw.githubusercontent.com/galiacheng/weblogic-azure/azure-lib-versions/weblogic-azure-aks/src/main/resources/azure-identity-provider-jdbc-mysql.xml"
export mvnVersion="3.8.6"
export mvnInstaller="apache-maven-${mvnVersion}-bin.tar.gz"
export mysqlDriverJarName="mysql-connector-java-8.0.30.jar"
export retryMaxAttempt=5 # retry attempt for curl command
export url4MavenInstaller="https://dlcdn.apache.org/maven/maven-3/${mvnVersion}/binaries/${mvnInstaller}"
export wlsMySQLDriverUrl="https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.30/mysql-connector-java-8.0.30.jar"
export wlsAdminURL=$wlsAdminHost:$wlsAdminPort

validate_input

if [ $databaseType == "mysql" ]; then
    upgrade_mysql_driver
fi

if [ "${enablePswlessConnection,,}" == "true" ]; then
    if [ $databaseType == "mysql" ]; then
        install_azure_mysql_libraries
    fi
fi

if [ $wlsServerName == "admin" ]; then
    restart_admin_service
else
    restart_managed_servers
fi
