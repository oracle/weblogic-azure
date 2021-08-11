// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// Deployment for pids.

param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '38647ff6-ea8d-59e5-832d-b036a4d29c73'
output appgwStart string = '8ba7beaa-96fd-576a-acd8-28f7a6efa83a'
output dbEnd string = 'ffab0a3f-90cb-585a-a7f9-ec0a62faeec1'
output dbStart string = 'e64361eb-fea0-5f15-a313-c76daadbc648'
output networkingEnd string = '39d32fcd-1d02-50b6-9455-4b767a8e769e'
output networkingStart string = 'ed47756f-2475-56dd-b13a-26027749b6e1'
output wlsAKSEnd string = '17328b4d-841f-57b5-a9c5-861ad48f9d0d'
output wlsAKSStart string = 'c46a11b1-e8d2-5053-9741-45294b2e15c9'
output wlsClusterAppEnd string = '18121d1c-4227-51ff-a9fa-ceb890d683e3'
output wlsClusterAppStart string = '4218fc54-4b9b-5e5c-b6a9-bc8736c25b68'
