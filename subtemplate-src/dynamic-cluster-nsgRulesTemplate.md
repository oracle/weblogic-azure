{% include variables.md %}

# Apply Azure Network Security Rule ARM Template to {{ site.data.var.wlsFullBrandName }}

This page documents how to append addtional security rules to an existing Azure Network Security Group deployed with {{ site.data.var.wlsFullBrandName }} using the Azure CLI.

## Prerequisies

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### Azure Network Security Group

The Azure Network Security Rule ARM template will be applied to an existing Azure Network Security Group (NSG) instance. If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Prepare the Parameters JSON file

You must construct a parameter JSON file containing the parameters to the NSG template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files. The options to this template declare the desired configuration of the NSG.

| Parameter Name | Description |
| `denyPublicTrafficForAdminServer` | Deny public tranffic for the admin server on port 7001, 7002. |
| `denyPublicTrafficForManagedServer` | Deny public tranffic for the managed servers on port 8001. |
| `enableOHS` | We deal with the configuration for managed servers when the OHS load balancer is enabled. |
| `networkSecurityGroupName` | The name of the NSG. |

#### Example Parameters JSON file

Here is a fully filled out parameters file, assuming the {{ site.data.var.wlsFullBrandName }} was deployed accepting the default values.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "denyPublicTrafficForManagedServer": {
            "value": true
        },
        "denyPublicTrafficForAdminServer": {
            "value": false
        },
        "enableOHS": {
            "value": true
        },
        "networkSecurityGroupName": {
            "value": "wls-nsg"
        }
    }
}
```

## Invoke the ARM template

This section shows how to kick off the deployment step-by-step. After the deployment, your existing NSG will append two additional Inbound Rules for admin and managed servers. Here we assume you have the parameter file in the current directory, the file is named `parameters.json`, and your NSG is named `wls-nsg`. Don't forget to replace `yourResourceGroup` with the Azure resource group in which the NSG is created.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/nsgNestedTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template with it

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/nsgNestedTemplate.json
```

## Verify the rules have been appended to the Azure Network Security Group successfully

When the deployment is completed, you can verify the appended rules via Azure Portal
* Visit the Azure Network Security Group under your resource group used above.
* Go to `Settings -> Inbound security rules`.
* Verify there is a rule named `WebLogicAdminPortsAllowed` with **Priority = '210'; Port = '7001, 7002'; Protocol = 'TCP'; Source = '10.0.0.0/24'; Aciton = 'Allow'**.
* Verify there is a rule named `WebLogicManagedPortsDenied` with **Priority = '221'; Port = '8001'; Protocol = '*'; Aciton = 'Deny'**.

