#!/bin/bash

function usage()
{
  echo "Usage: $0 <adminInternalHostName> <adminExternalHostName> <adminDnsZoneName> <dnsLabelPrefix> <wlsDomainName> <azureResourceGroupRegion> <adminVMNamePrefix> <globalResourceNameSuffix> [<debugFlag>]"
  exit 1
}


function readArgs()
{
  
  if [ $# -lt 6 ];
  then
    echo "Error !! invalid arguments"
    usage
  fi

  adminInternalHostName="$1"
  adminExternalHostName="$2"
  adminDNSZoneName="$3"
  dnsLabelPrefix="$4"
  wlsDomainName="$5"
  azureResourceGroupRegion="$6"
  adminVMNamePrefix=$7
  globalResourceNameSuffix="$8"

  if [ $# -gt 8 ];
  then
   debugFlag="$9"
  else
   debugFlag="false"
  fi
 
}


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

java -version > /dev/null 2>&1

if [ $? != 0 ];
then
  echo -e "Error !! This script requires java to be installed and available in the path for execution. \n Please install and configure JAVA in PATH variable and retry"
  exit 1
fi

if [ -z $WL_HOME ];
then
  echo -e "Error !! WL_HOME is not set. \nPlease ensure that WebLogic Server is installed and WL_HOME variable is set to the WebLogic Home Directory"
  exit 1
fi

#main

readArgs "$@"

echo "initializing ..."
CLASSES_DIR="$SCRIPT_DIR/classes"
mkdir -p "$CLASSES_DIR"

OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"

echo "Copying HostNames Template file ..."
cp -rf $SCRIPT_DIR/src/main/java/HostNameValuesTemplate.txt $SCRIPT_DIR/src/main/java/HostNameValues.java

cd $SCRIPT_DIR/src/main/java
echo "Compiling Default HostNameValues.java ..."
$JAVA_HOME/bin/javac -d $CLASSES_DIR HostNameValues.java

echo "Compiling WebLogicCustomHostNameVerifier.java "
$JAVA_HOME/bin/javac -d $CLASSES_DIR -classpath $WL_HOME/server/lib/weblogic.jar:$CLASSES_DIR WebLogicCustomHostNameVerifier.java

echo "generating weblogicustomhostnameverifier.jar"
cd $CLASSES_DIR
jar cf $OUTPUT_DIR/weblogicustomhostnameverifier.jar com/oracle/azure/weblogic/security/util/*.class

#replace arg values in HostNameValues.java
cp  $SCRIPT_DIR/src/main/java/HostNameValues.java $SCRIPT_DIR/src/main/java/HostNameValues.java.bak
sed -i "s/debugEnabled=.*/debugEnabled=${debugFlag};/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/adminInternalHostName=.*/adminInternalHostName=\"${adminInternalHostName}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/adminExternalHostName=.*/adminExternalHostName=\"${adminExternalHostName}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/adminDNSZoneName=.*/adminDNSZoneName=\"${adminDNSZoneName}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/dnsLabelPrefix=.*/dnsLabelPrefix=\"${dnsLabelPrefix}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/wlsDomainName=.*/wlsDomainName=\"${wlsDomainName}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/azureResourceGroupRegion=.*/azureResourceGroupRegion=\"${azureResourceGroupRegion}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/globalResourceNameSuffix=.*/globalResourceNameSuffix=\"${globalResourceNameSuffix}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java
sed -i "s/adminVMNamePrefix=.*/adminVMNamePrefix=\"${adminVMNamePrefix}\";/g" $SCRIPT_DIR/src/main/java/HostNameValues.java


cd $SCRIPT_DIR/src/main/java
echo "Compiling modified HostNameValues.java ..."
$JAVA_HOME/bin/javac -d $CLASSES_DIR HostNameValues.java

echo "generating hostnamevalues.jar"
cd $CLASSES_DIR
jar cf $OUTPUT_DIR/hostnamevalues.jar com/oracle/azure/weblogic/*.class

if [ $? != 0 ];
then
  echo "CustomHostNameVerifier jar creation Failed !! Please check the error and retry."
  exit 1
else
  echo "CustomHostNameVerifier jar created Successfully !!"
fi

echo "cleaning up existing classes ..."
find $CLASSES_DIR -type f -name "*.class" -delete

echo "Running HostNameVerifierTest ..."
cd $SCRIPT_DIR/src/test/java
$JAVA_HOME/bin/javac -d $CLASSES_DIR -classpath $OUTPUT_DIR/hostnamevalues.jar:$OUTPUT_DIR/weblogicustomhostnameverifier.jar WebLogicCustomHostNameVerifierTest.java

$JAVA_HOME/bin/java -classpath $CLASSES_DIR:$OUTPUT_DIR/hostnamevalues.jar:$OUTPUT_DIR/weblogicustomhostnameverifier.jar com.oracle.azure.weblogic.security.test.WebLogicCustomHostNameVerifierTest "$@"

if [ $? != 0 ];
then
  echo "CustomHostNameVerifierTest Failed !! Please check the error and retry."
  exit 1
else
  echo "CustomHostNameVerifierTest Passed Successfully !!"
fi

