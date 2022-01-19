# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

export checkPodStatusInterval=20 # interval of checking pod status.
export checkPodStatusMaxAttemps=30 # max attempt to check pod status.
export checkPVStateInterval=5 # interval of checking pvc status.
export checkPVStateMaxAttempt=10 # max attempt to check pvc status.
export checkSVCStateMaxAttempt=10
export checkSVCInterval=30 #seconds

export constAdminT3AddressEnvName="T3_TUNNELING_ADMIN_ADDRESS"
export constAdminServerName='admin-server'
export constClusterName='cluster-1'
export constClusterT3AddressEnvName="T3_TUNNELING_CLUSTER_ADDRESS"
export constDefaultJavaOptions="-Dlog4j2.formatMsgNoLookups=true -Dweblogic.StdoutDebugEnabled=false" # the java options will be applied to the cluster
export constDefaultJVMArgs="-Djava.security.egd=file:/dev/./urandom -Xms256m -Xmx512m -XX:MinRAMPercentage=25.0 -XX:MaxRAMPercentage=50.0 " # the JVM options will be applied to the cluster
export constFalse="false"
export constTrue="true"
export constIntrospectorJobActiveDeadlineSeconds=300  # for Guaranteed Qos

export curlMaxTime=120 # seconds
export ocrLoginServer="container-registry.oracle.com"
export ocrGaImagePath="middleware/weblogic"
export ocrCpuImagePath="middleware/weblogic_cpu"
export gitUrl4CpuImages="https://raw.githubusercontent.com/oracle/weblogic-azure/main/weblogic-azure-aks/src/main/resources/weblogic_cpu_images.json"
export optUninstallMaxTry=5 # Max attempts to wait for the operator uninstalled
export optUninstallInterval=10

export wlsContainerName="weblogic-server"
