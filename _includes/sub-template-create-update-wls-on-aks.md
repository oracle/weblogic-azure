## Prepare the Parameters

You must construct a parameters JSON file containing the parameters to be passed to the ARM template.
For background information about parameter files, see [Create Resource Manager parameter file](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/parameter-files). 
This section shows how to obtain the values for the required properties.

### Obtain parameter values from Azure portal

The first step is to obtain the parameter values from Azure portal, as Azure portal eases the interface and validation. 
You can define TLS/SSL configuration, Load Balancer setting, Application Gateway integration, custom DNS configuration and Database using the interface.

If you prefer to edit a json file, you can also create the objects in your parameter file directly. 

The following steps use the [Azure Create UI Definition Sandbox](https://portal.azure.com/?feature.customPortal=false#blade/Microsoft_Azure_CreateUIDef/SandboxBlade) to obtain the values. The Azure UI Definition Sandbox provides controls to select resources and input your values easily.  **More importantly, this approach generates syntactically valid JSON, eliminating an important class of data entry error.**

- Use your favourite browser and open the [Azure UI Definition Sandbox](https://portal.azure.com/?feature.customPortal=false#blade/Microsoft_Azure_CreateUIDef/SandboxBlade).

- Clear the content of Azure UI Definition Sandbox, and replace with the contents of this file: [createUiDefinition.json]({{ armTemplateBasePath }}createUiDefinition.json).

- Select **Preview**.

- Fill in the appropriate values. For guidance, see [running Oracle WebLogic Server on Azure Kuberneters Service document](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/).

  - **Basics** blade, configure the credentials for WebLogic and select User assigned managed identity.

    - If you are updating a WebLogic cluster, make sure you have right domain UID and domain name.

  - In the **Configure AKS cluter** blade, configure the AKS cluster, image selection and Java EE application selection.

    - If you are updating a WebLogic cluster, make sure you have selected the right AKS cluster and ACR.

  - In the **TLS/SSL configuration** blade, configure TLS/SSL certificates for Identity Key Store and Trust Key Store, which will be applied to WebLogic cluster.

  - In the **Networking** blade, configure Standard Load Balancer service and Application Gateway Ingress Controller.

  - In the **DNS configuration** blade, configure custom DNS alias for WebLogic Console portal and cluster.

  - In the **Database** blade, configure datasource connection. If you want to enable other database, select `Other` in **Choose database type** and finish the required inputs.

- Select **Review+create**, the Azure UI Definition Sandbox will validate the inputs, you must resolve any errors before proceeding.

  You will find a message "Validation Passed".

- **Here is the most important step:** Select **View outputs payload**, copy the payload and save it to a file named `parameters.json`

### Configure advanced parameters

| Advanced parameter Name | Explanation |
|----------------|-------------|
| `_artifactsLocation`| Required. See below for details. |
| `aciResourcePermissions`| Optinal. Boolean value. <br> The parameter activates when Azure Container Insight is enabled, `enableAzureMonitoring=true`. `false`: Set the workspace to workspace-context permissions. This is the default setting if the flag isn't set. `true`: Set the workspace to resource-context permissions. See [Azure Monitor access control mode](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/manage-access#configure-access-control-mode) |
| `aciRetentionInDays`| Optinal. Integer value. <br> Number of days to retain data in Azure Monitor workspace. |
| `aciWorkspaceSku`| Optinal. Enum value. <br> Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.. |
| `aksAgentPoolName` | Optinal. String value. <br> The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters. |
| `aksVersion`| Optinal. String value. <br> Version of Azure Kubernetes Service. Use default version if no specified value. |
| `enableAdminT3Tunneling`| Optinal. Boolean value. <br> Configure a custom channel in Admin Server for the T3 protocol that enables HTTP tunneling. |
| `enableClusterT3Tunneling` | Optinal. Boolean value. <br> Configure a custom channel in WebLogic cluster for the T3 protocol that enables HTTP tunneling. |
| `t3ChannelAdminPort` | Optinal. Integer value, 1-65535. <br> Sepcify cublic port of the custom T3 channel in admin server. |
| `t3ChannelClusterPort` | Optinal. Integer value, 1-65535. <br> Specify public port of the custom T3 channel in WebLoigc cluster. |
| `wlsCPU` | Optinal. String value. <br> Sepcify CPU requests for admin server and managed server pods. See [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)|
| `wlsMemory` | Optinal. String value. <br> Specify memory requests for admin server and managed server pods. See [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)|


#### `_artifactsLocation`

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

Append the expected advanced parameter to `parameters.json`. And make sure `_artifactsLocation` is presenting in `parameters.json`.
