<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% include variables.md %}

# Update the Java application in an existing {{ site.data.var.wlsFullBrandName }} 

This page documents how to update an existing deployment of {{ site.data.var.wlsFullBrandName }} with a Java EE applications using Azure CLI.

You can invoke this ARM template to:

- Update a running Java EE application with new version.

- Remove a running Java EE application.

- Deploy a new Java EE application.

The template will only update the application deployments in the {{ site.data.var.wlsFullBrandName }} cluster, without any change to other configuration.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

{% include sub-template-prerequisites-uami.md %}

{% include sub-template-prerequisites-wls.md %}

{% include sub-template-prerequisites-storage.md %}

## Prepare the Parameters JSON file

| Advanced parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| Required. See below for details. |
| `acrName` | Required. String value. <br> Name of Azure Container Registry that is used to managed the WebLogic domain images. |
| `aksClusterName`| Required. String value. <br> Name of the AKS cluster. Must be the same value provided at deployment time. |
| `aksClusterRGName` | Required. String value. <br> Name of resource group that contains the (AKS) instance, probably the resource group you are working on. It's recommended to run this template in the same resource group that runs AKS. |
| `identity` | Required. Object value. <br> Azure user managed identity used, make sure the identity has permission to create/update/delete Azure resources. It's recommended to assign "Contributor" role. |
| `wlsDomainName` | Required. String value. <br> Password for WebLogic Administrator. Make sure it's the same with the initial cluster deployment. |
| `wlsDomainUID` | Required. String value. <br> User name for WebLogic Administrator. Make sure it's the same with the initial cluster deployment. |
| `appPackageUrls`| Optinal. Array. <br> String array of Java EE applciation location, which can be downloaded using "curl". Currently, only support URLs of Azure Storage Account blob. |
| `appPackageFromStorageBlob`| Optinal. Object value. <br> Key `storageAccountName` specify the storage account name, the template will download application package from this storage account. <br> Key `containerName` specify the container name that stores the Java EE application. |
| `ocrSSOPSW` | Optional. String value. <br> Password for Oracle SSO account. |
| `ocrSSOUser` | Optional. String value. <br> User name for Oracle SSO account. |
| `wlsImageTag` | Optional. String value. <br> Docker tag that comes after "container-registry.oracle.com/middleware/weblogic:". |
| `userProvidedAcr` | Optional. String value. <br> User provided ACR for base image. |
| `userProvidedImagePath` | Optional. String value. <br> User provided base image path. |
| `useOracleImage` | Optional. Boolean value. <br> `true`: use Oracle standard images from Oracle Container Registry. <br> `false`: use user provided images from Azure Container Registry. |

### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```


### Java EE application location

The template supports two approaches to specify the location of Java EE application. 
The template will update the cluter with applications specified in `appPackageUrls` and `appPackageFromStorageBlob`.

#### SAS URLs

You can specify the application URLs via `appPackageUrls`. The template only supports url from Azure Storage Account. 
Make sure the URLs are accessible from public network. 
You may want to update one application, but you must include all the application SAS URLs in the parameter.
If you are removing an application, do not include the application url.

Steps to obtain SAS URLs:

  * Open your Storage Account from Azure portal. If you don't have, please follow this [guide](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) to create one.
  
  * Open your container. If you don't have, please follow this [guide](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) to create one.
  
  * You should find your application listed. If not, please upload your application package to the container:

    * Click **Upload**

    * Select the application file 

    * Click **Upload**

  * Click your application, and click **Generate SAS**.

    * Signing method: Account key

    * Signing key: Key 1

    * Permisson: Read

    * Click **Generate SAS token and URL**

    * Copy the **Blob SAS URL** and save it to a file.

  * Repeat step 4 for other applicatios.

  * Now you have all the URLs. `appPackageUrls` will be value like `["sasUrl1", "sasUrl2"]`.

    It should present in parameters.json like: 

    ```json
    {
        "appPackageUrls": {
            "value": [
                "sasUrl1", 
                "sasUrl2"
            ]
        }
    }
    ```

#### Storage Account Blob

You can also specify the contaier of Storage Account. The template will download all the .jar, .war. .ear files from the container.

You may want to update one application, but you must include all the application in the container.
If you want to remove an application, do not include the application.

Steps to upload your applications to blob:
  * Open your storage account from Azure portal. If you don't have, please follow [guide](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) to create one.
  
  * Create a new container follow [guide](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal) you may name it `javaeeapps`.

  * Upload your application to the container.

  * Now you can specify the value of storage blob: 

    * `storageAccountName`: name of your Storage Account

    * `containerName`: container name, should be `javaeeapps` if you use the name in step 2.

    It should present in parameters.json like: 

    ```json
    {
        "appPackageFromStorageBlob": {
            "value": {
                "storageAccountName": "<your-storage-account-name>",
                "containerName": "<your-container-name>"
            }
        }
    }
    ```

You can define the application location using both approaches, but it'not suggested. The template will download 
applications from `appPackageUrls` and `appPackageFromStorageBlob`.

### Base image location

The template supports two kinds of base image:

  - Oracle Standard image from Oracle Container Registry (OCR)

  - User provided image from Azure Container Registry (ACR)

#### Oracle Standard image

If you are using Oracle Standard image, you must provide the following parameters:

  - `ocrSSOPSW`: Password for Oracle SSO account. The template will use the account to pull image from OCR.

  - `ocrSSOUser`: User id for Oracle SSO account. The template will use the account to pull image from OCR.

  - `wlsImageTag`: weblogic image tag, the available tags are listed in [Oracle WebLogic Server images](https://container-registry.oracle.com/ords/f?p=113:4:3004995055779:::RP,4:P4_REPOSITORY,AI_REPOSITORY,P4_REPOSITORY_NAME,AI_REPOSITORY_NAME:5,5,Oracle%20WebLogic%20Server,Oracle%20WebLogic%20Server&cs=3ESIKaQQ31HlQbmvX7rymOn1zTwhKyMi5Y3TGWtMC0_2pGBgoBq1i3laSr5it036HJbbmsNugZLvrWuqQYU3T9A). Default value is `12.2.1.4`.

#### User provided image

If you are bringing your own image, you must provide the following parameters:

  - `userProvidedAcr`: ACR name that contains your image. The `acrName` should be the same ACR name.

  - `userProvidedImagePath`: image path in ACR.

  - `useOracleImage`: `false`

#### Example Parameters JSON

This is an example to deploy Java EE application in `samplecontainer` to the {{ site.data.var.wlsFullBrandName }} cluster, using Oracle base image.
The parameters using default value haven't been shown for brevity.

```json
{
    "_artifactsLocation": {
        "value": "{{ armTemplateBasePath }}"
    },
    "acrName": {
      "value": "sampleacr"
    },
    "aksClusterRGName": {
      "value": "sampleaksgroup"
    },
    "aksClusterName": {
      "value": "sampleaks"
    },
    "appPackageFromStorageBlob": {
      "value": {
        "storageAccountName": "samplestorage",
        "containerName": "samplecontainer"
      }
    },
    "identity": {
      "value": {
        "type": "UserAssigned",
        "userAssignedIdentities": {
          "/subscriptions/subscription-id/resourceGroups/samples/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azure_wls_aks": {}
        }
      }
    },
    "ocrSSOPSW": {
      "value": "Secret123!"
    },
    "ocrSSOUser": {
      "value": "foo@example.com"
    }
  }

```

## Invoke the ARM template

Assume your parameters file is available in the current directory and is named `parameters.json`.  This section shows the commands to configure your {{ site.data.var.wlsFullBrandName }} deployment with the specified database.  Replace `yourResourceGroup` with the Azure resource group in which the {{ site.data.var.wlsFullBrandName }} is deployed.

### Validate your parameters file

The `az group deployment validate` command is very useful to validate your parameters file is syntactically correct.

```bash
az deployment group validate --verbose \
  --resource-group `yourResourceGroup` \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}updateAppTemplate.json
```

If the command returns with an exit status other than `0`, inspect the output and resolve the problem before proceeding.  You can check the exit status by executing the commad `echo $?` immediately after the `az` command.

### Execute the template

After successfully validating the template invocation, change `validate` to `create` to invoke the template.

```bash
az deployment group create --verbose \
  --resource-group `yourResourceGroup` \
  --parameters @parameters.json \
  --template-uri {{ armTemplateBasePath }}updateAppTemplate.json
```

As with the validate command, if the command returns with an exit status other than `0`, inspect the output and resolve the problem.

For a successful deployment, you should find `"provisioningState": "Succeeded"` in your output.

## Verify application

Visit the application via cluster address, you should find your application have been updated.

