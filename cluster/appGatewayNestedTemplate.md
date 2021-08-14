{% include variables.md %}

# Apply Azure App Gateway ARM Template to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with Azure Application Gateway using the Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The Application Gateway ARM tempate will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Certificate for SSL Termination

Because the Application Gateway serves as the front end load balancer for the {{ site.data.var.wlsFullBrandName }} cluster, it must be provided with a certificate to allow browsers to connect via SSL.

When deploying the {{ site.data.var.wlsFullBrandName }} offer from the Azure Portal, you can configure the deployment to fetch the SSL certificate and its password from a pre-existing Azure Key Vault.  For a high-level introduction to SSL Certificates with Azure Key Vault see [Get started with Key Vault certificates](https://docs.microsoft.com/en-us/azure/key-vault/certificates/certificate-scenarios).  For an overview of TLS termination with Application Gateway see [Overview of TLS termination and end to end TLS with Application Gateway](https://docs.microsoft.com/en-us/azure/application-gateway/ssl-overview).  When configuring the Application Gateway after deployment, you must base64 encode the certificate and also know the password for the certificate.

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the database ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   We must specify the information of the existing SSL certificate. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `adminVMName`| At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `customDomainName`| Specify a custome domain name if want to override application gateway hostname. You are required to input the value if you use a pre-assigned SSL for application gateway. |
| `appGatewaySSLCertificateData`| See below for details. |
| `appGatewaySSLCertificatePassword`| See below for details. |
| `dnsNameforApplicationGateway`| (optional) A prefix value for the dns name of the Application Gateway. |
| `gatewayPublicIPAddressName` | (optional) A prefix value for the public IP address of the Application Gateway. |
| `location` | Must be the same region into which the server was initially deployed. |
| `managedServerPrefix` | At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `numberOfInstances` | The number of instances in the cluster.  Must be the same as the value used at deployment time. |
| `overrideHostName` | If `true` the template will override the application gateway hostname with value of `customDomainName`. The vaule should be `true` if you use a pre-assigned SSL for application gateway. |
| `wlsDomainName` | At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `wlsPassword` | Must be the same value provided at deployment time. |
| `wlsUserName` | Must be the same value provided at deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

### SSL Certificate Data and Password

Use base64 to encode your existing PFX format certificate.

```bash
base64 your-certificate.pfx -w 0 >temp.txt
```

Use the content as this file as the value of the `appGatewaySSLCertificateData` parameter.

It is assumed that you have the password for the certificate.  Use this as the value of the `appGatewaySSLCertificatePassword` parameter.

#### Example Parameters JSON

Here is a fully filled out parameters file.   Note that we did not include any optional parameters, assuming the {{ site.data.var.wlsFullBrandName }} was deployed accepting the default values.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation":{
            "value": "{{ armTemplateBasePath }}"
          },
        "appGatewaySSLCertificateData": {
             "value": "MIIKCQIB...sOr3QICCAA="
        },
        "appGatewaySSLCertificatePassword": {
             "value": "myPasswordInClearText"
        },
        "numberOfInstances": {
          "value": 3
        },
        "location": {
          "value": "eastus"
        },
        "wlsPassword": {
          "value": "welcome1"
        },
        "wlsUserName": {
          "value": "weblogic"
        }
    }
}
```

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with the specified database.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/appGatewayNestedTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/appGatewayNestedTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```json
{
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Resources/deployments/cli",
  "location": null,
  "name": "cli",
  "properties": {
    "correlationId": "4cc63f27-0f43-4244-9d89-a09bf417e943",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/publicIPAddresses/gwip",
            "resourceGroup": "oraclevm-cluster-0604",
            "resourceName": "gwip",
            "resourceType": "Microsoft.Network/publicIPAddresses"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/applicationGateways/myAppGateway",
        "resourceGroup": "oraclevm-cluster-0604",
        "resourceName": "myAppGateway",
        "resourceType": "Microsoft.Network/applicationGateways"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/applicationGateways/myAppGateway",
            "resourceGroup": "oraclevm-cluster-0604",
            "resourceName": "myAppGateway",
            "resourceType": "Microsoft.Network/applicationGateways"
          },
          {
            "apiVersion": "2019-11-01",
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/publicIPAddresses/gwip",
            "resourceGroup": "oraclevm-cluster-0604",
            "resourceName": "gwip",
            "resourceType": "Microsoft.Network/publicIPAddresses"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-cluster-0604",
        "resourceName": "adminVM/newuserscript",
        "resourceType": "Microsoft.Compute/virtualMachines/extensions"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-cluster-0604",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Resources/deployments/pid-36deb858-08fe-5c07-bc77-ba957a59a080",
        "resourceGroup": "oraclevm-cluster-0604",
        "resourceName": "pid-36deb858-08fe-5c07-bc77-ba957a59a080",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT8M41.2104793S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-cluster-0604"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/applicationGateways/myAppGateway",
        "resourceGroup": "oraclevm-cluster-0604"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-cluster-0604/providers/Microsoft.Network/publicIPAddresses/gwip",
        "resourceGroup": "oraclevm-cluster-0604"
      }
    ],
    "outputs": {
      "appGatewayURL": {
        "type": "String",
        "value": "http://wlsgw9e6ed1-oraclevm-cluster-0604-wlsd.eastus.cloudapp.azure.com"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "_artifactsLocationAGWTemplate": {
        "type": "String",
        "value": "{{ armTemplateBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "appGatewaySSLCertificateData": {
        "type": "String",
        "value": "MIIKQQIBAz....EkAgIIAA=="
      },
      "appGatewaySSLCertificatePassword": {
        "type": "String",
        "value": "myRedactedPassword"
      },
      "dnsNameforApplicationGateway": {
        "type": "String",
        "value": "wlsgw"
      },
      "gatewayPublicIPAddressName": {
        "type": "String",
        "value": "gwip"
      },
      "guidValue": {
        "type": "String",
        "value": "9e6ed15b-d386-4cb9-a617-3cb6f785f6a0"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "managedServerPrefix": {
        "type": "String",
        "value": "msp"
      },
      "numberOfInstances": {
        "type": "Int",
        "value": 4
      },
      "wlsDomainName": {
        "type": "String",
        "value": "wlsd"
      },
      "wlsPassword": {
        "type": "SecureString"
      },
      "wlsUserName": {
        "type": "String",
        "value": "weblogic"
      }
    },
    "parametersLink": null,
    "providers": [
      {
        "id": null,
        "namespace": "Microsoft.Resources",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              null
            ],
            "properties": null,
            "resourceType": "deployments"
          }
        ]
      },
      {
        "id": null,
        "namespace": "Microsoft.Network",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "publicIPAddresses"
          },
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "applicationGateways"
          }
        ]
      },
      {
        "id": null,
        "namespace": "Microsoft.Compute",
        "registrationPolicy": null,
        "registrationState": null,
        "resourceTypes": [
          {
            "aliases": null,
            "apiVersions": null,
            "capabilities": null,
            "locations": [
              "eastus"
            ],
            "properties": null,
            "resourceType": "virtualMachines/extensions"
          }
        ]
      }
    ],
    "provisioningState": "Succeeded",
    "template": null,
    "templateHash": "12239709219097081949",
    "templateLink": null,
    "timestamp": "2020-06-04T03:17:01.168329+00:00"
  },
  "resourceGroup": "oraclevm-cluster-0604",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify Application Gateway

We will deploy a testing application to verify if the appliaction gateway is enabled.

Go to Admin Server Console and deploy [webtestapp.war](../resources/webtestapp.war).

* Visit the {{ site.data.var.wlsFullBrandName }} Admin console.
* Select **Deployments**.
* Select **Install**.
* Select file `webtestapp.war`.
* Select **Next**.  Choose "Install this deployment as an application".
* Select **Next**. Select "cluster-1" and "All servers in the cluster".
* Keep configuration as default and select **Finish**.
* Select **Activate Changes**
* In the left navigation pane, select **Deployments**.
* Select **Control**
* Select `webtestapp`
* Select **Start**
* Select **Servicing all requests**

Then access the application with `<appGatewayHost>/webtestapp`, you will get a page with server host information if application gateway was successfully enabled.
