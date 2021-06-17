// Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

// Deployment for pids.

param name string = 'pid'

// create a pid deployment if there is a specified name
module pidStart './_empty.bicep' = if (name != 'pid'){
  name: name
}

output wlsAKSEnd string = '17328b4d-841f-57b5-a9c5-861ad48f9d0d'
output wlsAKSStart string = 'c46a11b1-e8d2-5053-9741-45294b2e15c9'
