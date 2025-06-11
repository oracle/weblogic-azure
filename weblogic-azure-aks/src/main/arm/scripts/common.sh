# Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

export checkPodStatusInterval=20 # interval of checking pod status.
export checkPodStatusMaxAttemps=200 # max attempt to check pod status.
export checkPVStateInterval=5 # interval of checking pvc status.
export checkPVStateMaxAttempt=10 # max attempt to check pvc status.
export checkSVCStateMaxAttempt=50
export checkSVCInterval=30 #seconds
export checkAGICStatusMaxAttempt=10
export checkAGICStatusInterval=30
export checkIngressStateMaxAttempt=50
export checkAcrInterval=30
export checkAcrMaxAttempt=10
export checkAgicInterval=30
export checkAgicMaxAttempt=50
export checkKedaInteval=30
export checkKedaMaxAttempt=20

export constAdminT3AddressEnvName="T3_TUNNELING_ADMIN_ADDRESS"
export constAdminServerName='admin-server'
export constClusterName='cluster-1'
export constClusterT3AddressEnvName="T3_TUNNELING_CLUSTER_ADDRESS"
export constARM64Platform="arm64"
export constX86Platform="amd64"
export constMultiArchPlatform="Multi-architecture"
export constDBTypeMySQL="mysql"
export constDBTypeSqlServer="sqlserver"
export constDefaultJavaOptions="-Dlog4j2.formatMsgNoLookups=true -Dweblogic.StdoutDebugEnabled=false" # the java options will be applied to the cluster
export constDefaultJVMArgs="-Djava.security.egd=file:/dev/./urandom -Xms256m -Xmx512m -XX:MinRAMPercentage=25.0 -XX:MaxRAMPercentage=50.0 " # the JVM options will be applied to the cluster
export constDefaultAKSVersion="default"
export externalJDBCLibrariesDirectoryName="externalJDBCLibraries"
export constFalse="false"
export constTrue="true"
export constIntrospectorJobActiveDeadlineSeconds=300  # for Guaranteed Qos
export constPostgreDriverName="postgresql-42.7.5.jar"
export constMSSQLDriverName="mssql-jdbc-12.8.1.jre11.jar"
export constAzureCoreVersion="1.34.0"
export constDbPodIdentitySelector="db-pod-identity" # do not change the value
export constPreclassDirectoryName="preclassLibraries"
export constLivenessProbePeriodSeconds=30
export constLivenessProbeTimeoutSeconds=5
export constLivenessProbeFailureThreshold=20
export constReadinessProbeProbePeriodSeconds=10
export constReadinessProbeTimeoutSeconds=5
export constReadinessProbeFailureThreshold=3

export curlMaxTime=120 # seconds
export ocrLoginServer="container-registry.oracle.com"
export ocrGaImagePath="middleware/weblogic"
export ocrCpuImagePath="middleware/weblogic_cpu"
export gitUrl4CpuImages="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/weblogic_cpu_images.json"
export gitUrl4AksWellTestedVersionJsonFile="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/aks_well_tested_version.json"
export gitUrl4AksToolingWellTestedVersionJsonFile="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/aks_tooling_well_tested_versions.json"
export gitUrl4WLSToolingFamilyJsonFile="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/weblogic_tooling_family.json"
export gitUrl4AzureIdentityExtensionsPomFile="https://raw.githubusercontent.com/oracle/weblogic-azure/b67a5f95a6c2f590fe8ff938daa298fe7adf7a45/weblogic-azure-aks/src/main/resources/azure-identity-extensions.xml" # PR https://github.com/oracle/weblogic-azure/pull/352 "https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/azure-identity-extensions.xml"
export gitUrl4MySQLDriverPomFile="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/mysql-connector-java.xml"

export optUninstallMaxTry=5 # Max attempts to wait for the operator uninstalled
export optUninstallInterval=10

export retryMaxAttempt=5 # retry attempt for curl command
export retryInterval=10

export wlsContainerName="weblogic-server"
export wlsPostgresqlDriverUrl="https://jdbc.postgresql.org/download/postgresql-42.7.5.jar"
export wlsMSSQLDriverUrl="https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar"
# The azure-identity is required by specified MSSQL driver, see https://learn.microsoft.com/en-us/sql/connect/jdbc/connecting-using-azure-active-directory-authentication?view=sql-server-ver17#connect-using-activedirectorymanagedidentity-authentication-mode 
export azureIdentityForMSSQLUrl="https://repo1.maven.org/maven2/com/azure/azure-identity/1.12.2/azure-identity-1.12.2.jar"
export jdkArm64Url="https://aka.ms/download-jdk/microsoft-jdk-11.0.23-linux-aarch64.tar.gz"
