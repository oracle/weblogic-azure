/* 
 Copyright (c) 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _pidCPUUtilization string = ''
param _pidEnd string = ''
param _pidMemoryUtilization string = ''
param _pidStart string = ''
param _pidWme string = ''

param aksClusterName string 
param aksClusterRGName string
param azCliVersion string

@allowed([
  'cpu'
  'memory'
])
param hpaScaleType string = 'cpu'
param identity object = {}
param location string
param useHpa bool 
param utilizationPercentage int
param wlsClusterSize int
param wlsDomainUID string
@secure()
param wlsPassword string
param wlsUserName string

var const_namespace = '${wlsDomainUID}-ns'

module pidAutoScalingStart './_pids/_pid.bicep' = {
  name: 'pid-auto-scaling-start'
  params: {
    name: _pidStart
  }
}

module pidCpuUtilization './_pids/_pid.bicep' = if(useHpa && hpaScaleType == 'cpu') {
  name: 'pid-auto-scaling-based-on-cpu-utilization'
  params: {
    name: _pidCPUUtilization
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module pidMemoryUtilization './_pids/_pid.bicep' = if(useHpa && hpaScaleType == 'memory') {
  name: 'pid-auto-scaling-based-on-memory-utilization'
  params: {
    name: _pidMemoryUtilization
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module pidWme './_pids/_pid.bicep' = if(!useHpa) {
  name: 'pid-auto-scaling-based-on-java-metrics'
  params: {
    name: _pidWme
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module hapDeployment '_deployment-scripts/_ds_enable_hpa.bicep' = if(useHpa) {
  name: 'hpa-deployment'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: azCliVersion
    hpaScaleType: hpaScaleType
    identity: identity
    location: location
    utilizationPercentage: utilizationPercentage
    wlsClusterSize: wlsClusterSize
    wlsNamespace: const_namespace
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}

module promethuesKedaDeployment '_enablePromethuesKeda.bicep' = if (!useHpa) {
  name: 'promethues-keda-weblogic-monitoring-exporter-deployment'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: azCliVersion
    identity: identity
    location: location
    wlsClusterSize: wlsClusterSize
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    pidAutoScalingStart
  ]
}



module pidAutoScalingEnd './_pids/_pid.bicep' = {
  name: 'pid-auto-scaling-end'
  params: {
    name: _pidEnd
  }
  dependsOn: [
    hapDeployment
    promethuesKedaDeployment
  ]
}

output kedaScalerServerAddress string = useHpa ? '' : promethuesKedaDeployment.outputs.kedaScalerServerAddress
output base64ofKedaScalerSample string = useHpa ? '' : promethuesKedaDeployment.outputs.base64ofKedaScalerSample
