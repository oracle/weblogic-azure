{% include variables.md %}

# Add nodes to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} to add add new managed application nodes using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Azure Active Directory LDAP Instance

Refer to [Azure Active Directory(AAD) LDAP Instance](aadNestedTemplate.html#azure-active-directory-ldap-instance).

### Administering Security for Oracle WebLogic Server & Configuring KeyStores

Refer to [Configuring Keystores](https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/12.2.1.4/secmg/identity_trust.html).

### Generate Base64 string for a given ssl certificate/keystore file

Use the following command to generate a Base64 string for a given ssl certificate/keystore file, to be used as input in the parameters JSON file

<pre>base64 /my/path/your-certificate.cer -w 0 >temp.txt</pre>


## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the add-node ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   You must specify the information of the existing {{ site.data.var.wlsFullBrandName }} and nodes that to be added. This section shows how to obtain the values for the following required properties.

<table>
 <tr>
  <td>Parameter Name</td>
  <td colspan="2">Explanation</td>
 </tr>
 <tr>
  <td><code>_artifactsLocation</code></td>
  <td colspan="2">See below for details.</td>
 </tr>
 <tr>
  <td rowspan="5"><code>aadsSettings</code></td>
  <td colspan="2">Optional. <a href="https://docs.microsoft.com/en-us/azure/architecture/building-blocks/extending-templates/objects-as-parameters">JSON object type</a>. You can specify this parameters for Azure Active Directory integration. If <code>enable</code> is true, must specify other properties. See the page <a href="https://docs.microsoft.com/en-us/azure/developer/java/migration/migrate-weblogic-with-aad-ldap">WebLogic to Azure with AAD via LDAP</a> for further information.</td>
 </tr>
 <tr>

  <td><code>enable</code></td>
  <td>If <code>enable</code> is true, must specify all properties of the <code>aadSettings</code>.</td>
 </tr>
 <tr>

  <td><code>publicIP</code></td>
  <td>The public IP address of Azure Active Directory LDAP server.</td>
 </tr>
 <tr>

  <td><code>serverHost</code></td>
  <td>The server host of Azure Active Directory LDAP server.</td>
 </tr>
  <tr>

  <td><code>certificateBase64String</code></td>
  <td>The based64 string of LADP client certificate that will be imported to trust store of WebLogic Server to enable SSL connection of AD provider.</td>
 </tr>
 <tr>
  <td><code>adminPasswordOrKey</code></td>
  <td colspan="2">Password of administration account for the new Virtual Machine that host new nodes.</td>
 </tr>
 <tr>
  <td><code>adminURL</code></td>
  <td colspan="2">The URL of WebLogic Administration Server, usually made up with Virtual Machine name and port, for example: <code>adminVM:7001</code>.</td>
 </tr>
 <tr>
  <td rowspan="7"><code>elkSettings</code></td>
  <td colspan="2">Optional. <a href="https://docs.microsoft.com/en-us/azure/architecture/building-blocks/extending-templates/objects-as-parameters">JSON object type</a>. You can specify this parameters for Elasticsearch and Kibana(ELK) connection. If <code>enable</code> is true, must specify other properties. See the page <a href="https://aka.ms/arm-oraclelinux-wls-elk">WebLogic with Elastic on Azure</a> for further information.</td>
 </tr>
 <tr>

  <td><code>enable</code></td>
  <td>If <code>enable</code> is true, must specify all properties of the <code>elkSettings</code>.</td>
 </tr>
 <tr>

  <td><code>elasticsearchEndpoint</code></td>
  <td>Endpoint of the Elasticsearch instance.</td>
 </tr>
 <tr>

  <td><code>elasticsearchPassword</code></td>
  <td>Password for Elasticsearch account.</td>
 </tr>
 <tr>

  <td><code>elasticsearchUserName</code></td>
  <td>User name for Elasticsearch account.</td>
 </tr>
 <tr>

  <td><code>logIndex</code></td>
  <td>Must be the same value output at ELK deployment time. </td>
 </tr>
 <tr>

  <td><code>logsToIntegrate</code></td>
  <td>Array with string value. Specify the expeted logs to integrate, you must input at least one log.</td>
 </tr>
 <tr>
  <td><code>numberOfExistingNodes</code></td>
  <td colspan="2">The number of existing managed application nodes, used to generate new virtual machine name,.</td>
 </tr>
 <tr>
  <td><code>numberOfNewNodes</code></td>
  <td colspan="2">The number of nodes to add.</td>
 </tr>
 <tr>
  <td><code>storageAccountName</code></td>
  <td colspan="2">The name of an existing storage account.</td>
 </tr>
 <tr>
  <td><code>wlsDomainName</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
 <tr>
  <td><code>wlsUserName</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
 <tr>
  <td><code>wlsPassword</code></td>
  <td colspan="2">Must be the same value provided at deployment time.</td>
 </tr>
 <tr>
  <td rowspan="10"><code>customSSLSettings</code></td>
  <td colspan="2">Optional. <a href="https://docs.microsoft.com/en-us/azure/architecture/building-blocks/extending-templates/objects-as-parameters">JSON object type</a>. You can specify this parameters for configuring Custom SSL Settings for WebLogic Administration Server. If <code>enable</code> is true, must specify other properties. See the page <a href="https://docs.oracle.com/en/middleware/fusion-middleware/weblogic-server/12.2.1.4/secmg/identity_trust.html">Administering Security for Oracle WebLogic Server and Configuring Keystores</a> for further information.</td>
 </tr>
 <tr>
  <td><code>enable</code></td>
  <td>If <code>enable</code> is true, must specify all properties of the <code>customSSLSettings</code>.
      &nbsp;Set to <code>false</code> by default.</td>
 </tr>
 <tr>
  <td><code>customIdentityKeyStoreBase64String</code></td>
  <td>The based64 string of the custom identity keystore file that will be configured in the WebLogic Administration Server to enable SSL connection.</td>
 </tr>
 <tr>
  <td><code>customIdentityKeyStorePassPhrase</code></td>
  <td>The identity keystore pass phrase</td>
 </tr>
 <tr>
  <td><code>customIdentityKeyStoreType</code></td>
  <td>Identity Key Store Type. This can be either JKS or PKCS12</td>
 </tr>
 <tr>
  <td><code>customTrustKeyStoreBase64String</code></td>
  <td>The based64 string of the custom trust keystore file that will be configured in the WebLogic Administration Server to enable SSL connection.</td>
 </tr>
 <tr>
  <td><code>customTrustKeyStorePassPhrase</code></td>
  <td>The trust keystore pass phrase</td>
 </tr>
  <tr>
  <td><code>customTrustKeyStoreType</code></td>
  <td>Trust Key Store Type. This can be either JKS or PKCS12</td>
 </tr>
 <tr>
  <td><code>privateKeyAlias</code></td>
  <td>The private key alias</td>
 </tr>
 <tr>
  <td><code>privateKeyPassPhrase</code></td>
  <td>The private Key Pass phrase.</td>
 </tr>
</table>

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateAddNodeBasePath }}
```

### Existing managed application servers
To differentiate functionality of managed servers, we use **managed application server** to represent managed servers that host Java EE application, and use **managed cache server** to represent managed servers that used for cache.

You can get the existing managed application nodes with the following command:

```shell
$ resourceGroup=<your-resource-group>
$ managedServerPrefix=<managed-server-prefix>
$ numberOfExistingNodes=$(az resource list -g ${resourceGroup} --resource-type Microsoft.Compute/virtualMachines --query [*].name | grep "${managedServerPrefix}VM[0-9]" | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' ' | sed 's/ /\n/g' | sort  -nr | head -n1)
$ echo ${numberOfExistingNodes}
```

### Log index

If you configured ELK in your cluster to export WebLogic Server logs to ELK, please input the value of Kibana log index, this template will set up ELK connection and export logs to specified index.

You can get the value from Azure portal with the following steps:

* Go to Azure portal.
* Open you resource group and click **Deployments**.
* Open the ELK deployment, and click **Output**.
* Copy the value of `logIndex`.

Alternatively, use Azure CLI command to list log index inside the resource group deployments:

```shell
$ az deployment group list -g 'yourResourceGroup' --query [*].properties.outputs.logIndex.value
[
  "azure-weblogic-cluster-f984df74-ab4d-4c17-a532-7f248659fb28"
]
```

### Storage account

Each Storage Account handles up to 20,000 IOPS, and 500TB of data. If you use a storage account for Standard Virtual Machines, you can store until 40 virtual disks.

We have two disks for one Virtual Machine, it's suggested no more than 20 Virtual Machines share the same storage account. Number of virtual machines that hosting managed servers should be less than or equal to 20.

You can get the name of storage account from Azure portal with steps:

  * Go to Azure portal
  * Go to the your resource group
  * Find storage account resource and copy its name

Alternatively, use Azure CLI command to list storage account inside a resource group:

```shell
$ az resource list -g 'yourResourceGroup' --resource-type Microsoft.Storage/storageAccounts --query [*].name
[
  "219846olvm"
]
```

#### Example Parameters JSON

Here is a fully filled out parameters file, with Azure Active Directory enabled. We will leave values of `adminUsername`, `authenticationType`, `dnsLabelPrefix`, `managedServerPrefix`, `skuUrnVersion`, `usePreviewImage` and `vmSizeSelect` as default value. 

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "_artifactsLocation": {
            "value": "{{ armTemplateAddNodeBasePath }}"
        },
        "aadsSettings": {
            "value": {
                "enable": true,
                "publicIP":"13.68.244.90",
                "serverHost": "ladps.wls-security.com",
                "certificateBase64String":"LS0tLS1C...tLS0tLQ0K"
            }
        },
        "adminPasswordOrKey": {
            "value": "Secret123!"
        },
        "adminURL":{
            "value": "adminVM:7001"
        },
        "elkSettings": {
            "value": {
                "enable": true,
                "elasticsearchEndpoint":"https://example.eastus2.azure.elastic-cloud.com:9243",
                "elasticsearchPassword": "Secret123!",
                "elasticsearchUserName":"elastic",
                "logIndex": "azure-weblogic-dynamic-cluster-11122020",
                "logsToIntegrate": ["HTTPAccessLog", "ServerLog", "DomainLog", "DataSourceLog", "StandardErrorAndOutput", "NodeManagerLog"]
            }
        },
        "location": {
            "value": "eastus"
        },
        "numberOfExistingNodes": {
            "value": 4
        },
        "numberOfNewNodes": {
          "value": 3
        },
        "storageAccountName": {
            "value": "496dfdolvm"
        },
        "wlsDomainName": {
            "value": "wlsd"
        },
        "wlsUserName": {
            "value": "weblogic"
        },
        "wlsPassword": {
            "value": "welcome1"
        },
        "customSSLSettings": {
            "value": {
                "enable": true,
                "customIdentityKeyStoreBase64String": "/u3+7QAAAAIAAAABAAAAAQAKc2VydmV....QZL24ljJLq",
                "customIdentityKeyStorePassPhrase": "mypassword",
                "customIdentityKeyStoreType": "JKS",
                "customTrustKeyStoreBase64String": "/u3+7QAAAAIAAAABAAAAAgAJdHJ1c3R....Td4bYVnONyS0PC7k=",
                "customTrustKeyStorePassPhrase": "mypassword",
                "customTrustKeyStoreType": "JKS",
                "privateKeyAliasSecret": "servercert",
                "privateKeyPassPhraseSecret": "mypassword"
            }
       }
    }
}
```

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment to add new nodes.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az group deployment validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateAddNodeBasePath }}arm/mainTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az group deployment create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateAddNodeBasePath }}arm/mainTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```bash
{
  "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Resources/deployments/mainTemplate",
  "location": null,
  "name": "mainTemplate",
  "properties": {
    "correlationId": "54517529-a1c4-422f-a539-23b9a5129e80",
    "debugSetting": null,
    "dependencies": [
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7/extensions/newuserscript",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "mspVM7/newuserscript",
            "resourceType": "Microsoft.Compute/virtualMachines/extensions"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Resources/deployments/pid-c7671c10-ae59-5ec5-bff3-c60db22d7ea4",
        "resourceGroup": "oraclevm-dcluster-0727",
        "resourceName": "pid-c7671c10-ae59-5ec5-bff3-c60db22d7ea4",
        "resourceType": "Microsoft.Resources/deployments"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Network/publicIPAddresses/mspVM7_PublicIP",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "mspVM7_PublicIP",
            "resourceType": "Microsoft.Network/publicIPAddresses"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Network/networkInterfaces/mspVM7_NIC",
        "resourceGroup": "oraclevm-dcluster-0727",
        "resourceName": "mspVM7_NIC",
        "resourceType": "Microsoft.Network/networkInterfaces"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Network/networkInterfaces/mspVM7_NIC",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "mspVM7_NIC",
            "resourceType": "Microsoft.Network/networkInterfaces"
          },
          {
            "apiVersion": "2019-06-01",
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Storage/storageAccounts/09b943olvm",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "09b943olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7",
        "resourceGroup": "oraclevm-dcluster-0727",
        "resourceName": "mspVM7",
        "resourceType": "Microsoft.Compute/virtualMachines"
      },
      {
        "dependsOn": [
          {
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "mspVM7",
            "resourceType": "Microsoft.Compute/virtualMachines"
          },
          {
            "actionName": "listKeys",
            "apiVersion": "2019-04-01",
            "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Storage/storageAccounts/09b943olvm",
            "resourceGroup": "oraclevm-dcluster-0727",
            "resourceName": "09b943olvm",
            "resourceType": "Microsoft.Storage/storageAccounts"
          }
        ],
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7/extensions/newuserscript",
        "resourceGroup": "oraclevm-dcluster-0727",
        "resourceName": "mspVM7/newuserscript",
        "resourceType": "Microsoft.Compute/virtualMachines/extensions"
      }
    ],
    "duration": "PT9M6.8098765S",
    "mode": "Incremental",
    "onErrorDeployment": null,
    "outputResources": [
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7",
        "resourceGroup": "oraclevm-dcluster-0727"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Compute/virtualMachines/mspVM7/extensions/newuserscript",
        "resourceGroup": "oraclevm-dcluster-0727"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Network/networkInterfaces/mspVM7_NIC",
        "resourceGroup": "oraclevm-dcluster-0727"
      },
      {
        "id": "/subscriptions/05887623-95c5-4e50-a71c-6e1c738794e2/resourceGroups/oraclevm-dcluster-0727/providers/Microsoft.Network/publicIPAddresses/mspVM7_PublicIP",
        "resourceGroup": "oraclevm-dcluster-0727"
      }
    ],
    "outputs": {
      "wlsDomainLocation": {
        "type": "String",
        "value": "/u01/domains/wlsd"
      }
    },
    "parameters": {
      "_artifactsLocation": {
        "type": "String",
        "value": "{{ armTemplateAddNodeBasePath }}"
      },
      "_artifactsLocationSasToken": {
        "type": "SecureString"
      },
      "aadsSettings": {
        "type": "Object",
        "value": {
          "certificateBase64String": "LS0tLS1C...S0tLQ0K",
          "enable": true,
          "publicIP": "40.76.11.111",
          "serverHost": "ladps.wls-security.com"
        }
      },
      "adminPasswordOrKey": {
        "type": "SecureString"
      },
      "adminURL": {
        "type": "String",
        "value": "adminVM:7001"
      },
      "adminUsername": {
        "type": "String",
        "value": "weblogic"
      },
      "authenticationType": {
        "type": "String",
        "value": "password"
      },
      "dnsLabelPrefix": {
        "type": "String",
        "value": "wls"
      },
      "guidValue": {
        "type": "String",
        "value": "67657ba3-6248-46e5-bedc-53e16ac82571"
      },
      "location": {
        "type": "String",
        "value": "eastus"
      },
      "managedServerPrefix": {
        "type": "String",
        "value": "msp"
      },
      "numberOfExistingNodes": {
        "type": "Int",
        "value": 7
      },
      "numberOfNewNodes": {
        "type": "Int",
        "value": 1
      },
      "skuUrnVersion": {
        "type": "String",
        "value": "owls-122130-8u131-ol74;Oracle:weblogic-122130-jdk8u131-ol74:owls-122130-8u131-ol7;1.1.1"
      },
      "storageAccountName": {
        "type": "String",
        "value": "09b943olvm"
      },
      "usePreviewImage": {
        "type": "Bool",
        "value": false
      },
      "vmSizeSelect": {
        "type": "String",
        "value": "Standard_A3"
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
      },
      "customSSLSettings": {
        "type": "Object",
        "value": {
           "enable": true,
           "customIdentityKeyStoreBase64String": "/u3+7QAAAAIAAAABAAAAAQAKc2VydmV....QZL24ljJLq",
           "customIdentityKeyStorePassPhrase": "mypassword",
           "customIdentityKeyStoreType": "JKS",
           "customTrustKeyStoreBase64String": "/u3+7QAAAAIAAAABAAAAAgAJdHJ1c3R....Td4bYVnONyS0PC7k=",
           "customTrustKeyStorePassPhrase": "mypassword",
           "customTrustKeyStoreType": "JKS",
           "privateKeyAliasSecret": "servercert",
           "privateKeyPassPhraseSecret": "mypassword"
        }
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
            "resourceType": "networkInterfaces"
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
            "resourceType": "virtualMachines"
          },
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
    "templateHash": "15879952829017360289",
    "templateLink": {
      "contentVersion": "1.0.0.0",
      "uri": "{{ armTemplateAddNodeBasePath }}arm/mainTemplate.json"
    },
    "timestamp": "2020-07-27T12:37:03.733682+00:00"
  },
  "resourceGroup": "oraclevm-dcluster-0727",
  "type": "Microsoft.Resources/deployments"
}
```

## Verify

### Verify if new nodes are added to the WebLogic Server instance.

* Go to the {{ site.data.var.wlsFullBrandName }} Administration Console.
* Go to **Environment -> Machines**.
  You should see logical machines with suffix from `numberOfExistingNodes` to `numberOfExistingNodes + numberOfNewNodes` are added.
  Make note of the total number of machines.

* Scale up to check if the machines work
    * Go to **Environment** -> **Cluster** -> `cluster1` -> **Control** -> **Scaling**. 

        Input value to **Desired Number of Running Servers** with the total number of machines, saved in last step.
    * Save and activate.
    * Go to **Environment** -> **Servers**.
    
        Expected result: the running managed server number is the same as machine total number. And there are servers running on the new managed nodes.

### Verify if Azure resources are added

* Go to [Azure Portal](https://ms.portal.azure.com/).
* Go to resource group that the {{ site.data.var.wlsFullBrandName }} is deployed.

  You should see corresponding Vitual Machines, Disks, Network Interfaces, Public IPs have been added.

### Verify AAD Integration

Verify AAD integration by delpoying a simple Java EE applciation with basic authentication.

* Go to Administration Server Console and deploy [testing application](../resources/basicauth.war).
  * Select **Deployments**.
  * Select **Install**.
  * Select file `basicauth.war`.
  * Select **Next**.  Choose "Install this deployment as an application".
  * Select **Next**. Select "cluster-1" and "All servers in the cluster".
  * Keep configuration as default and select **Finish**.
  * Select **Activate Changes**
  * In the left navigation pane, select **Deployments**.
  * Select **Control**
  * Select `basicauth`
  * Select **Start**
  * Select **Servicing all requests**

* Access the sample application
  * Go to Administration Server Console
  * Go to **Environment -> Machines**. Click one of the new machines, make sure there are servers running on that machine. Click **Node Manager** and make note of the machine host in **Listen Address**, here named it as `machineName`. Click **Servers** and make note of **Listen Port**, here named it as `port`.
  * Go to [Azure Portal](https://ms.portal.azure.com/), and get DNS name from Virtual Machine has the same name of `machineName`, named it `machineDNS`  
  * Go to `http://${machineDNS}:${port}/basicauth`, the browser will prompt up to ask for credentials, input one of AAD users from group **AAD DC Administrators**, note that use name should be **sAMAccountName**, for example `wlstest` for user `wlstest@javaeehotmailcom.onmicrosoft.com`.
  * Expected result, you can access the sample application without error.
