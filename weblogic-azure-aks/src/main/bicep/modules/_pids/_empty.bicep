// Copyright (c) 2021, Oracle Corporation and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

/*
* Used to create an empty deployment
* Example: 
* module emptyDeployment './empty.bicep' = {
*   name: name
* }
*/

// Workaround to arm-ttk complain: Parameters property must exist in the template
param name string = 'This is an empty deployment'

output name string = name
