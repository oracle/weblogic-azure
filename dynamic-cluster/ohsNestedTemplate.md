
{% include variables.md %}

# Apply OHS ARM Template to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with a Oracle HTTP Server using Azure CLI.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Certificate for SSL Termination

Oracle HTTP Server serves as the front end load balancer for the {{ site.data.var.wlsFullBrandName }} dynamic cluster, hence it must be provided with a certificate to allow browsers to connect via SSL.

#### Creating Self-signed certificate

This section describes how to create a self-signed certificate in the format expected by Oracle HTTP server. The example provided below is one of the ways to create self-signed certificates. Note that such self-signed certificates created should only be used for testing purpose and it is not recommended for production purpose.

* JKS format certificate

   ```bash
   keytool -genkey -keyalg RSA -alias selfsigned -keystore keyStore.jks -storepass password -validity 360 -keysize 2048
   ```
 
   Provide all information prompted and store in a file.

* PKCS12 format certificate

   ```bash
   openssl req -newkey rsa:2048 -x509 -keyout key.pem -out out.pem -days 3650
   ```

   Provide all information prompted and store in a file.

## Prepare the Parameters JSON file

You must construct a parameters JSON file containing the parameters to the OHS ARM template.  See [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files) for background information about parameter files.   We must specify the information of the existing SSL certificate. This section shows how to obtain the values for the following required properties.

| Parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| See below for details. |
|`adminPasswordOrKey`|Password of administration account for the new Virtual Machine that hosts Oracle HTTP Server.|
|`adminUsername`| Username of administration account for the new Virtual Machine that hosts Oracle HTTP Server.|
|`adminRestMgmtURL`| WebLogic Server admin REST management URL. It should be in the format `http://admincomputername:adminport/management/weblogic/latest`.Example  `http://adminVM:7001/management/weblogic/latest` or `http://adminVM:7005/management/weblogic/latest` |
|`dnsLabelPrefix`| Must be the same `dnsLabelPrefix` value with which WebLogic Dynamic cluster deployment is made. This value is used for fetching existing deployment `dnsLabelPrefix-nsg` NSG value. |
|`location`| Must be the same region into which the WebLogic dynamic cluster deployment is made.|
|`ohsComponentName` | Oracle HTTP Server component name to be configured as part of domain. At deployment, if this value is changed from its default value, the value used at deployment time must be used.|
|`ohsDomainName`| Oracle HTTP Server standalone domain name. At deployment, if this value is changed from its default value, the value used at deployment time must be used.  |
|`ohsNMPassword`| Oracle HTTP Server NodeManager password configured as part of the domain. |
|`ohsNMUser`| Oracle HTTP Server NodeManager user name configured as part of the domain.|
|`keyType` | Certificate format supported for configuring Oracle HTTP Server SSL configuration. Supported format is `JKS` and `PKCS12`. Default value is `PKCS12`|
|`ohsSSLKeystoreData`| base64 bit encoded value of JKS/PKCS12 certificate contents. See below for details|
|`ohsSSLKeystorePassword`|The keystore stored password |
|`ohsSkuUrnVersion`| Oracle HTTP Server base images provided by publisher Oracle. Refer [Azure Marketplace OHS Base Images](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=oracle%20ohs%20base%20image) |
|`ohsVMName`|At deployment time, if this value is changed from its default value, the value used at deployment time must be used. Otherwise, this parameter should be omitted.|
|`ohshttpPort` | Http server port configured using which application can be accessed via Oracle HTTP Server.At deployment, if this value is changed from its default value, the value used at deployment time must be used.|
|`ohshttpsPort`| Https server port configured using which application can be accessed via Oracle HTTP Server.At deployment, if this value is changed from its default value, the value used at deployment time must be used.|
|`oracleVaultPswd` | Password for Oracle wallet/vault, to add certificates supplied for OHS.|
|`storageAccountName`| The name of an existing storage account. Must be the same storage account name avilable in existing deployed WebLogic dynamic cluster|
|`virtualNetworkName`| The name of an existing virtual network name. Must be the same virtual network name available in existing deployed WebLogic dynamic cluster|
|`wlsUserName` |Must be the same value provided at deployment time for WebLogic dynamic cluster deployment time.|
|`wlsPassword` |Must be the same value provided at deployment time WebLogic dynamic cluster deployment time.|


### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

### `ohsSSLKeystoreData`
Use base64 to encode your existing SSL certificate.

<code> base64 your-JKS/PKCS12-certificate-contents -w 0 > temp.txt </code>

Use temp.txt contents to set the value for ohsSSLKeystoreData

#### Example Parameters JSON

Here is a fully filled out parameters file.   Note that we did not include any optional parameters, assuming the {{ site.data.var.wlsFullBrandName }} was deployed accepting the default values.


```json
{
  "_artifactsLocation": {
    "value": "{{ armTemplateBasePath }}"
  },
  "adminPasswordOrKey": {
    "value": "Azure123456!"
  },
  "adminRestMgmtURL": {
    "value": "http://adminVM:7001/management/weblogic/latest"
  },
  "adminUsername": {
    "value": "azureuser"
  },
  "dnsLabelPrefix": {
    "value": "wls"
  },
  "keyType": {
    "value": "JKS"
  },
  "location": {
    "value": "eastus"
  },
  "ohsComponentName": {
    "value": "ohs_component"
  },
  "ohsDomainName": {
    "value": "ohsStandaloneDomain"
  },
  "ohsNMPassword": {
    "value": "Nmpswd1234567"
  },
  "ohsNMUser": {
    "value": "weblogic"
  },
  "ohsSSLKeystoreData": {
    "value": "/u3+7QAAAAIAAAABAAAAAQAKc2VsZnNpZ25lZAAAAX ...."
  },
  "ohsSSLKeystorePassword": {
    "value": "azure123!"
  },
  "ohsSkuUrnVersion": {
    "value": "ohs-122140-jdk8-ol76;ohs-122140-jdk8-ol76;latest"
  },
  "ohsVMName": {
    "value": "ohsVM"
  },
  "ohshttpPort": {
    "value": "7777"
  },
  "ohshttpsPort": {
    "value": "4444"
  },
  "oracleVaultPswd": {
    "value": "Welcome1234567"
  },
  "storageAccountName":  {
    "value": "6be282olvm"
  },
  "virtualNetworkName": {
    "value": "wlsd_VNET"
  },
  "wlsPassword": {
    "value": "Welcome1234567"
  },
  "wlsUserName": {
    "value": "weblogic"
  }
}
```

### Invoke the ARM template
Assume your parameters file is available in the current directory and is named parameters.json. This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with a Oracle HTTP Server. Replace yourResourceGroup with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### First, validate your parameters file
The `az deployment group validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/ohsNestedTemplate.json
```
If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Next, execute the template
After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose --resource-group `yourResourceGroup` --parameters @parameters.json --template-uri {{ armTemplateBasePath }}nestedtemplates/ohsNestedTemplate.json
```
As with the validate command, if the command returns with an exit status other than 0, inspect the output and resolve the problem.

This is an example output of successful deployment.  Look for `"provisioningState": "Succeeded"` in your output.

```bash
    "provisioningState": "Succeeded",
    "template": null,
    "templateHash": "13760326614657528322",
```

## Verify Oracle HTTP Server setup

Successful deployment provides Oracle HTTP Server access url in your output, similar to below.

```json
      "ohsAccessURL": {
        "type": "String",
        "value": "http://wls-5ff4cab395-loadbalancer.eastus.cloudapp.azure.com:7777"
      },
      "ohsSecureAccessURL": {
        "type": "String",
        "value": "https://wls-5ff4cab395-loadbalancer.eastus.cloudapp.azure.com:4444"
      }
```

Follow the steps to verify Oracle HTTP Server.
* Visit the {{ site.data.var.wlsFullBrandName }} Admin console.
* In the left navigator, expand the tree to select **Deployments**, install some sample application targeted to WebLogic Cluster and start the service.
* Access your application using <code>ohsAccessURL/application</code> 
* Access your application using <code>ohsSecureAccessURL/application</code> 

