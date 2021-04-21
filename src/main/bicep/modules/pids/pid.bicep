// Deployment for pids.

param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './empty.bicep' = if (name != 'pid'){
  name: name
}

output wlsAKSEnd string = '2571f846-2f66-5c22-9fe6-38ecea7889ac'
output wlsAKSStart string = '3e6acde5-9a62-5488-9fd4-87c46f4105f4'
