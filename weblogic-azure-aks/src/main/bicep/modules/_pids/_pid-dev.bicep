// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// Deployment for pids.

param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output appgwEnd string = '38647ff6-ea8d-59e5-832d-b036a4d29c73'
output appgwStart string = '8ba7beaa-96fd-576a-acd8-28f7a6efa83a'
output customCertForAppgw string = 'b16ba29f-fc8e-5059-8988-f17bef4a9c5c'
output dbEnd string = 'ffab0a3f-90cb-585a-a7f9-ec0a62faeec1'
output dbStart string = 'e64361eb-fea0-5f15-a313-c76daadbc648'
output dnsEnd string = '189306c7-39e2-5844-817d-01e883a4cf1e'
output dnsStart string = '8ae63711-9fa7-56b4-a4a0-236f3ccef542'
output lbEnd string = 'f76e2847-d5a1-52e7-9e52-fc8560f5d3e4'
output lbStart string = 'e2a8c8b2-9b58-52c6-9636-1834ff3976dc'
output networkingEnd string = '39d32fcd-1d02-50b6-9455-4b767a8e769e'
output networkingStart string = 'ed47756f-2475-56dd-b13a-26027749b6e1'
output otherDb string = '551122ff-2fea-53a8-b7f4-6d6dae85af6a'
output pswlessDbEnd string = '7e7aaa5b-2251-55b5-8b3d-43d514738cf2'
output pswlessDbStart string = '089e9783-6707-54d0-ac8c-9b8d517914c5'
output sslEnd string = 'fd285d8c-8d24-5d4e-b9f9-81f252ebfc6d'
output sslStart string = 'eb67405c-3276-53bb-b1bc-db6dad811d71'
output wlsAKSEnd string = '17328b4d-841f-57b5-a9c5-861ad48f9d0d'
output wlsAKSStart string = 'c46a11b1-e8d2-5053-9741-45294b2e15c9'
output wlsClusterAppEnd string = '18121d1c-4227-51ff-a9fa-ceb890d683e3'
output wlsClusterAppStart string = '4218fc54-4b9b-5e5c-b6a9-bc8736c25b68'
