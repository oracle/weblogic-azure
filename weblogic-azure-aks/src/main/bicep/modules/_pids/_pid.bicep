// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// Deployment for pids.

param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '47ea43a0-95cf-52c7-aee8-7ee6106fc1bf'
output appgwStart string = '01288010-2672-5831-a66b-7b8b45cace1b'
output dbEnd string = 'd7a9c78e-39d9-5a47-928d-8645ed86dafd'
output dbStart string = '0cc86800-37f4-5191-9368-2953394309ec'
output dnsEnd string = '754e16bc-4d81-5343-b99b-7532abd6587d'
output dnsStart string = '64ae895c-feb3-529e-8435-5d2e49f94e09'
output lbEnd string = 'ce664543-77bd-515a-832e-107e32f99da9'
output lbStart string = '44732bbc-04c4-5df7-a0c6-b9be9ec00ee6'
output networkingEnd string = '2798165c-49fa-5701-b608-b80ed3986176'
output networkingStart string = '0793308f-de9d-5f0d-92f9-d9fc4b413b8b'
output pswlessDbEnd string = '972084b9-2b2d-5eb9-aa37-80448a77fbe1'
output pswlessDbStart string = '7190b263-7825-5ae3-bc56-7294df936d4a'
output wlsAKSEnd string = '2571f846-2f66-5c22-9fe6-38ecea7889ac'
output wlsAKSStart string = '3e6acde5-9a62-5488-9fd4-87c46f4105f4'
output wlsClusterAppEnd string = 'e6e33240-e5db-52fc-9154-7fc7b3b8b508'
output wlsClusterAppStart string = '4570a81a-3f3a-53d5-b178-7f985d9c5ecf'
