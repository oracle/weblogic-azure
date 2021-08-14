{% include variables.md %}

# Apply Azure Active Directory ARM Template to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with an existing Azure Active Directory Domain Service (AAD DS) using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The AAD ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Azure Active Directory LDAP Instance

To apply AAD to {{ site.data.var.wlsFullBrandName }}, you must have an existing Azure Active Directory LDAP instance to use. If you don't have AAD LADP instance, please follow the steps in the tutorial [Configure secure LDAP for an Azure Active Directory Domain Services managed domain](https://docs.microsoft.com/en-us/azure/active-directory-domain-services/tutorial-configure-ldaps).

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the AAD ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   We must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and AAD instance. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
| `aadsPortNumber` | (optional) The LDAP port number, defaults to 636. | 
| `aadsPublicIP` | The IP address of the LDAP server |
| `aadsServerHost` | The hostname of the Active Directory Domain Services server. |
| `adminVMName`| At deployment time, if this value was changed from its default value, the value used at deployment time must be used.  Otherwise, this parameter should be omitted. |
| `location` | Must be the same region into which the server was initially deployed. |
| `wlsDomainName` | The name of the {{ site.data.var.wlsFullBrandName }} domain. |
| `wlsLDAPGroupBaseDN` | The base distinguished name (DN) of the tree in the LDAP directory that contains groups. |
| `wlsLDAPPrincipalPassword` | The credential (usually a password) used to connect to the LDAP server. |
| `wlsLDAPPrincipal` | The Distinguished Name (DN) of the LDAP user that {{ site.data.var.wlsFullBrandName }} should use to connect to the LDAP server. |
| `wlsLDAPProviderName` | (optional) The value used for creating authentication provider name of WebLogic Server. |
| `wlsLDAPSSLCertificate` | Client certificate that will be imported to trust store of SSL. |
| `wlsLDAPSSLCertificate` | See below for details. |
| `wlsLDAPUserBaseDN` | The base distinguished name (DN) of the tree in the LDAP directory that contains users. |
| `wlsPassword` | Must be the same value provided at deployment time. |
| `wlsUserName` | Must be the same value provided at deployment time. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

### `wlsLDAPSSLCertificate`

Use base64 to encode your existing SSL certificate.

```bash
base64 your-certificate.cer -w 0 >temp.txt
```

Use the content as this file as the value of the `wlsLDAPSSLCertificate` parameter.

#### Example Parameters JSON

Here is a fully filled out parameters file.   Note that we did not include values for parameters that have a default value.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateBasePath }}"
        },
        "aadsPublicIP": {
            "value": "1.2.3.4"
        },
        "aadsServerHost": {
           "value": "ladps.fabrikam.com"
        },
        "location": {
            "value": "eastus"
        },
        "wlsDomainName": {
          "value": "adminDomain"
        },
        "wlsLDAPGroupBaseDN": {
            "value": "OU=AADDC Users,DC=fabrikam,DC=com"
        },
        "wlsLDAPPrincipal": {
            "value": "CN=WLSTest,OU=AADDC Users,DC=fabrikam,DC=com"
        },
        "wlsLDAPPrincipalPassword": {
            "value": "Secret123!"
        },
        "wlsLDAPSSLCertificate": {
            "value": "MIIKQQIBAz....EkAgIIAA=="
        },
        "wlsLDAPUserBaseDN": {
            "value": "OU=AADDC Users,DC=fabrikam,DC=com"
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

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with the specified AAD.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/aadNestedTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/aadNestedTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```json
{
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-06082/providers/Microsoft.Resources/deployments/cli",
  "location": null,
  "name": "cli",
  "properties": {
    "correlationId": "6d98e1c8-0778-4fa5-a30a-8f10bbbb6818",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-06082/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
            "resourceGroup": "oraclevm-admin-06082",
            "resourceName": "adminVM/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-06082/providers/Microsoft.Resources/deployments/pid-8295df19-fe6b-5745-ad24-51ef66522b24",
        "resourceGroup": "oraclevm-admin-06082",
        "resourceName": "pid-8295df19-fe6b-5745-ad24-51ef66522b24",
        "resourceType": "Microsoft.Resources/deployments"
      }
    ],
    "duration": "PT2M59.6052694S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-admin-06082/providers/Microsoft.Compute/virtualMachines/adminVM/extensions/newuserscript",
        "resourceGroup": "oraclevm-admin-06082"
      }
    ],
    "outputs": {
      "artifactsLocationPassedIn": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      },
      "_artifactsLocationAADTemplate": {
        "type": "String",
        "value": "https://raw.githubusercontent.com/galiacheng/arm-oraclelinux-wls-admin/deploy/src/main/arm/"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "aadsPortNumber": {
        "type": "String",
        "value": "636"
      },
      "aadsPublicIP": {
        "type": "String",
        "value": "40.76.11.111"
      },
      "aadsServerHost": {
        "type": "String",
        "value": "ladps.wls-security.com"
      },
      "adminVMName": {
        "type": "String",
        "value": "adminVM"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "wlsDomainName": {
        "type": "String",
        "value": "adminDomain"
      },
      "wlsLDAPGroupBaseDN": {
        "type": "String",
        "value": "OU=AADDC Users,DC=wls-security,DC=com"
      },
      "wlsLDAPPrincipal": {
        "type": "String",
        "value": "CN=WLSTest,OU=AADDC Users,DC=wls-security,DC=com"
      },
      "wlsLDAPPrincipalPassword": {
        "type": "SecureString"
      },
      "wlsLDAPProviderName": {
        "type": "String",
        "value": "AzureActiveDirectoryProvider"
      },
      "wlsLDAPSSLCertificate": {
        "type": "String",
        "value": "LS0tLS1...LQ0K"
      },
      "wlsLDAPUserBaseDN": {
        "type": "String",
        "value": "OU=AADDC Users,DC=wls-security,DC=com"
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
    "templateHash": "2818584196763146470",
    "templateLink": null,
    "timestamp": "2020-06-09T07:07:03.444046+00:00"
  },
  "resourceGroup": "oraclevm-admin-06082",
  "type": "Microsoft.Resources/deployments"
}

```

## Verify AAD Integration

Follow the steps to check if AAD is enabled.

* Visit the {{ site.data.var.wlsFullBrandName }} Admin console.
* In the left navigator, expand the tree to select **Security Realms** -> **myrealm** -> **Providers**.
* If the integration was successful, you will find the AAD provider for example `AzureActiveDirectoryProvider`.
* In the left navigator, expand the tree to select **Security Realms** -> **myrealm** -> **Users and Groups**.
* If the integration was successful, you will find users from the AAD provider.
