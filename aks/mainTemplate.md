<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Advanced actions with Oracle WebLogic Server cluster on {{ site.data.var.aksFullName }}

This document describes how to create an {{ site.data.var.wlsFullBrandName }} cluster on {{ site.data.var.aksFullName }} using the Azure CLI.

## Introduction

{% include sub-template-advanced-usage.md %}

This document will guide you to create a WebLogic Server cluster in ways that supplement and enhance the capabilities offered by the Azure Marketplace offer. The techniques described in this document go beyond what you can configure using the Azure Marketplace offer.

## Prerequisites

This section lists several prerequisites for activating the features as described in the guidance.  Optional prerequisites are marked as (optional)

{% include sub-template-prerequisites.md %}

{% include sub-template-create-update-wls-on-aks.md %}

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`. 
This section shows the commands to create an {{ site.data.var.wlsFullBrandName }} cluster on AKS.

Use the command to create a resoruce group.

```shell
resourceGroupName="hello-wls-aks"
az group create --name ${resourceGroupName} -l eastus
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
