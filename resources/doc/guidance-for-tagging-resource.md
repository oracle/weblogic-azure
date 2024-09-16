
# Guidance on Applying Tags in Solution Templates

## What are Tags in this context and why are they useful?

Tags are arbitrary name=value pairs that can be associated with most Azure resources. Azure features such as Azure Policy can use Tags to enforce cloud governance policies. For more about tags, see [Use tags to organize your Azure resources and management hierarchy](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources).

## Step 1: Audit Resources Created in the Offer

To determine the resources that will be created in your offer, use the following commands based on the template type:

### For ARM Templates:
Use the command below to list resource types:

```bash
# Navigate to the offer folder
cd offer-folder
grep -rh "\"type\": \"Microsoft" --exclude="createUiDefinition.json" | sort | uniq | sed 's/^[ \t]*//'
```

### For Bicep Templates:
Use the command below to list resource types and remove duplicates:

```bash
# Navigate to the offer folder
cd offer-folder
grep -rh "^resource" | grep "Microsoft." | sort | uniq | sed 's/^[ \t]*//'
```

Identify which resources support tags and which do not. For resources not listed below, consult the ARM definition at [Azure Resource Manager templates](https://learn.microsoft.com/en-us/azure/templates/) to determine if tagging is supported. If the definition does not include a tags property, the resource does not support tags and tagging is not required for deployments.

### Resources that Support Tags:

The top-level resources will be listed in the Tag UI control. Sub-resources will inherit the same tags as their parent resources.

For example, in the UI definition, customers can specify tags for `Microsoft.KeyVault/vaults`, but not for `Microsoft.KeyVault/vaults/secrets`. For the deployment of `Microsoft.KeyVault/vaults/secrets`, the same tags applied to `Microsoft.KeyVault/vaults` will be used. This approach ensures a consistent tagging experience with Key Vault deployments in the Azure portal.

- Microsoft.Network/dnszones
- Microsoft.Network/networkInterfaces
- Microsoft.Network/networkSecurityGroups
- Microsoft.Network/publicIPAddresses
- Microsoft.Network/privateEndpoints
- Microsoft.Storage/storageAccounts
- Microsoft.KeyVault/vaults
    - Microsoft.KeyVault/vaults/secrets
- Microsoft.Network/virtualNetworks
- Microsoft.Compute/virtualMachines
- Microsoft.Compute/virtualMachines/extensions
- Microsoft.Resources/deploymentScripts
- Microsoft.ManagedIdentity/userAssignedIdentities
- Microsoft.Resources/deployments
- Microsoft.Network/applicationGateways

### Resources that Do Not Support Tags:

- Microsoft.Storage/storageAccounts/fileServices
- Microsoft.Storage/storageAccounts/fileServices/shares
- Microsoft.Network/networkSecurityGroups/securityRules
- Microsoft.Network/dnsZones/A
- Microsoft.Network/dnszones/CNAME
- Microsoft.Network/virtualNetworks/subnets
- Microsoft.Authorization/roleAssignments
- Microsoft.Network/loadBalancers/backendAddressPools
- Microsoft.Network/applicationGateways/backendHttpSettingsCollection
- Microsoft.Network/applicationGateways/frontendIPConfigurations
- Microsoft.Network/applicationGateways/frontendPorts
- Microsoft.Network/applicationGateways/gatewayIPConfigurations
- Microsoft.Network/applicationGateways/httpListeners
- Microsoft.Network/applicationGateways/probes
- Microsoft.Network/applicationGateways/requestRoutingRules

## Step 2: Tag UI Control

Incorporate the [Microsoft.Common.TagsByResource UI element](https://learn.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/microsoft-common-tagsbyresource?WT.mc_id=Portal-Microsoft_Azure_CreateUIDef0) to include resources that support tags.

## Step 3: Update the Template

Refer to the WLS PR to apply tags to the resource deployments appropriately.

## Step 4: Testing

1. **Create a Test Offer:** Set up a test offer to validate the tagging process.
  
2. **Tag Settings:**
    - Apply a uniform tag to all resources.
    - Create specific tags for each resource, setting the tag value to the resource type (e.g., "tag1=storage account").
  
3. **Deploy the Offer:** 

4. **Verify Tags:** Use the following command to verify that the resources have the correct tags applied:

    ```bash
    az resource list --resource-group <resource-group-name> --query "[].{Name:name, Type:type, Tags:tags}" -o json
    ```

    For example:

    ```shell
    az resource list --resource-group haiche-sn-tag-test --query "[].{Name:name, Type:type, Tags:tags}" -o json
    [
        {
            "Name": "0733ecolvm",
            "Tags": {
            "Tag0": "All",
            "Tag6": "storage account"
            },
            "Type": "Microsoft.Storage/storageAccounts"
        },
        {
            "Name": "olvm_PublicIP",
            "Tags": {
            "Tag0": "All",
            "Tag4": "public ip address"
            },
            "Type": "Microsoft.Network/publicIPAddresses"
        },
        {
            "Name": "wls-nsg",
            "Tags": {
            "Tag0": "All",
            "Tag3": "network security group"
            },
            "Type": "Microsoft.Network/networkSecurityGroups"
        },
        {
            "Name": "olvm_VNET",
            "Tags": {
            "Tag0": "All",
            "Tag8": "virtual network"
            },
            "Type": "Microsoft.Network/virtualNetworks"
        },
        {
            "Name": "olvm_NIC",
            "Tags": {
            "Tag0": "All",
            "Tag2": "network interface"
            },
            "Type": "Microsoft.Network/networkInterfaces"
        },
        {
            "Name": "WeblogicServerVM",
            "Tags": {
            "Tag0": "All",
            "Tag7": "virtual machine"
            },
            "Type": "Microsoft.Compute/virtualMachines"
        },
        {
            "Name": "WeblogicServerVM_OsDisk_1_d1fed748ccaa4cac81df9179e6dff325",
            "Tags": {
            "Tag0": "All",
            "Tag7": "virtual machine"
            },
            "Type": "Microsoft.Compute/disks"
        }
    ]
    ```
