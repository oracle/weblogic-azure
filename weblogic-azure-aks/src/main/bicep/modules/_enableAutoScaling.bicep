/* 
 Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
param _pidEnd string = ''
param _pidStart string = ''
param _pidCPUUtilization string = ''
param _pidMemoryUtilization string = ''
param _pidWme string = ''








