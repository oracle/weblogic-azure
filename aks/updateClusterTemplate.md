<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Post deployment actions for Oracle WebLogic Server cluster on {{ site.data.var.aksFullName }}

This page documents how to update Oracle WebLogic cluster on {{ site.data.var.aksFullName }} with advanced configuration using Azure CLI.

## Introduction

{% include sub-template-advanced-usage.md %}

While, there are some limitations:

- No support to update a WebLogic cluster using older weblogic version, for example, you can not downgrade a 14.1.1.0 cluster to 12.2.1.4.

- If you have enabled Azure Application Gatway Ingress Controller, you can not update the WebLogic cluster with TLS/SSL enabled to a cluster without TLS/SSL, otherwise, ingress will fail, you have to create new ingress for HTTP access.

- You have to specify all required parameters, even though you are not going to update some of them.

This document will guide you to update a WebLogic cluster using the advanced configurations.

## Prerequisites

{% include sub-template-prerequisites.md %}

## Updating the existing WebLogic Server cluster

The template will apply the new configuration in `parameters.json` to the running WebLogic cluster, please double check that you have specified:

- The same credentials for WebLogic
- The same domain name and domain UID.
- The same AKS and ACR.

Parameters to specify WebLogic credentials:

```json
{
  "wdtRuntimePassword": {
    "value": "Secret123!"
  },
  "wlsPassword": {
    "value": "Secret123!"
  },
  "wlsUserName": {
    "value": "weblogic"
  }
}
```

Parameters for AKS and ACR should look like:

```json
{
  "acrName": {
      "value": "<your-acr-name>"
  },
  "aksClusterName": {
    "value": "<your-aks-name>"
  },
  "aksClusterRGName": {
    "value": "<your-aks-resource-group>"
  },
  "createACR": {
    "value": false
  },
  "createAKSCluster": {
    "value": false
  }
}
```

Parameters for domain should look like, ignore them if you used the default values:

```json
{
  "wlsDomainName": {
    "value": "domain2"
  },
  "wlsDomainUID": {
    "value": "sample-domain2"
  }
}
```

{% include sub-template-create-update-wls-on-aks.md %}

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`. 
This section shows the commands to create WebLogic cluster on AKS.

Set resource group name, should be the one running your AKS cluster.

```shell
resourceGroupName="hello-wls-aks"
```

### Validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose \
  --resource-group ${resourceGroupName} \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}mainTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose \
  --resource-group ${resourceGroupName} \
  --name advanced-deployment \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}mainTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

After a successful deployment, you should find `"provisioningState": "Succeeded"` in your output.


## Verify deployment

The sample has set up custom T3 channel for Administration Server and cluster, you should be able to access Administration Console portal 
using the public address of T3 channel.

Obtain the address from deployment output:

  - Open your resource group from Azure portal.
  - Click **Settings** -> **Deployments** -> the deployment with name `advanced-deployment`, listed in the bottom.
  - Click **Outputs** of the deployment, copy the value of `adminServerT3ExternalUrl`

Get public IP and port from `adminServerT3ExternalUrl`, access `http://<public-ip>:<port>/console` from browser, you should find the login page.
