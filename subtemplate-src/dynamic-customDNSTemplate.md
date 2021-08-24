{% include variables.md %}

# Configure DNS alias to {{ site.data.var.wlsFullBrandName }}

This page documents how to configure an existing deployment of {{ site.data.var.wlsFullBrandName }} with a custom DNS alias.

## Prerequisites

### Environment for Setup

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure), use `az --version` to test if `az` works.

### WebLogic Server Instance

The DNS Configuraton ARM template will be applied to an existing {{ site.data.var.wlsFullBrandName }} instance.  If you don't have one, please create a new instance from the Azure portal, by following the link to the offer [in the index](index.md).

### Registered Domain Name

You need to buy a domain name to create a custom DNS alias.

### Azure DNS Zone

If you create the DNS alias on an existing [Azure DNS Zone](https://docs.microsoft.com/en-us/azure/dns/dns-overview), make sure you have perfomed the [Azure DNS Delegation](https://docs.microsoft.com/en-us/azure/dns/dns-domain-delegation).  Once you have completed the delegation, you can verify it with `nslookup`.  For example, assuming your domain name is **contoso.com**, this output shows a correct delegation.

```bash
$ nslookup -type=SOA contoso.com
Server:         172.29.80.1
Address:        172.29.80.1#53

Non-authoritative answer:
contoso.com
        origin = ns1-01.azure-dns.com
        mail addr = azuredns-hostmaster.microsoft.com
        serial = 1
        refresh = 3600
        retry = 300
        expire = 2419200
        minimum = 300
Name:   ns1-01.azure-dns.com
Address: 40.90.4.1
Name:   ns1-01.azure-dns.com
Address: 2603:1061::1
```

We strongly recommand you create an Azure DNS Zone for domain management and reuse it for other perpose. Follow the [guide](https://docs.microsoft.com/en-us/azure/dns/dns-getstarted-portal) to create an Azure DNS Zone.

### Azure Managed Indentify

If you are going to configure DNS alias based on an existing DNS Zone, you are required to input the ID of a user-assigned managed identity. 

Follow this [guide](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal) to create a user-assigned managed identity.

To obtain ID of the indentify: go to Azure Portal; open the identity **Overview** page; click **JSON View** and copy the **Resource ID**.


## Prepare the Parameters

We provide an automation shell script for DNS configuration. You must specify the information of the existing Oracle WebLogic Server. This section shows how to obtain the values for the following required properties.

| Parameter&nbsp;Name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Explanation |
|----------------|-------------|
| `--admin-vm-name`| Required. Name of vitual machine that hosts {{ site.data.var.wlsFullBrandName }} admin server. Must be the same value provided at initial deployment time.|
| `--admin-console-label` | Required. Label for {{ site.data.var.wlsFullBrandName }} admin console. Used to generate subdomain of admin console. | 
| `--artifact-location`| Required. See below for details. |
| `--resource-group` | Required. Name of resource group that has WebLogic cluster deployed. |
| `--location` | Required. Must be the same region into which the server was initially deployed. |
| `--zone-name` | Required. Azure DNS Zone name. |
| `--ohs-vm-name` | Optional. Specify name of the VM that hosts the Oracle HTTP Server Load Balancer. |
| `--loadbalancer-label` | Optional. Label for Load Balancer. Used to generate subdomain of application gateway. The parameter is only required if you want to create DNS alias for application gateway.|
| `--identity-id` | Optional. ID of Azure user-assigned managed identity. The parameter is only required if you are creating DNS alias on an existing DNS Zone.|
| `--zone-resource-group` | Optional. Name of resource group that has Azure DNS Zone deployed. The parameter is only required if you are creating DNS alias on an existing DNS Zone. |
| `--help` | Help. |

### Artifacts location

This value must be the following.

```bash
{{ armTemplateBasePath }}
```

## Invoke the Automation Script

We provide an automation script to configure a custom DNS alias. The script lets you do the following:

  * If you have an Azure DNS Zone, it will create a DNS alias for the admin console and application gateway on the existing DNS Zone.
  * If you don't have an Azure DNS Zone, it will create the DNS Zone in the same resource group as the WebLogic cluster, then create the DNS alias for the admin console and application gateway.

### Configure DNS Alias on an Existing Azure DNS Zone

To configure a DNS alias on an existing Azure DNS Zone, in addition to the required parameters, you must also specify an Azure user-assigned managed identity ID and the resource group name in which your DNS Zone is deployed.

This is an example to create a DNS alias `admin.contoso.com` for the admin console and `applciations.contoso.com` for the application gateway on an existing Azure DNS Zone.

```bash
$ curl -fsSL {{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/cli-scripts/custom-dns-alias-cli.sh \
  | /bin/bash -s -- \
  --resource-group `yourResourceGroup` \
  --admin-vm-name adminVM \
  --admin-console-label admin \
  --artifact-location {{ armTemplateBasePath }} \
  --location eastus \
  --zone-name contoso.com \
  --ohs-vm-name ohsVM \
  --loadbalancer-label applications \
  --identity-id `yourIndentityID` \
  --zone-resource-group `yourDNSZoneResourceGroup`
```

An example output:

```text
Done!

Custom DNS alias:
    Resource group: haiche-dns-doc
    WebLogic Server Administration Console URL: http://admin.contoso.com:7001/console
    WebLogic Server Administration Console secured URL: https://admin.contoso.com:7002/console
  

    Application Gateway URL: http://applications.contoso.com:7777
    Application Gateway secured URL: https://applications.contoso.com:4444
```


### Configure DNS Alias on a New Azure DNS Zone

To configure a DNS alias on a new Azure DNS Zone, you must specify the required parameters.

This is an example of creating an Azure DNS Zone, then creating a DNS alias `admin.contoso.com` for the admin console and `applications.contoso.com` for application gateway. 

```bash
$ curl -fsSL {{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/cli-scripts/custom-dns-alias-cli.sh \
  | /bin/bash -s -- \
  --resource-group `yourResourceGroup` \
  --admin-vm-name adminVM \
  --admin-console-label admin \
  --artifact-location {{ armTemplateBasePath }} \
  --location eastus \
  --zone-name contoso.com \
  --ohs-vm-name ohsVM \
  --loadbalancer-label applications
```

An example output:

```text
DONE!
  

Action required:
  Complete Azure DNS delegation to make the alias accessible.
  Reference: https://aka.ms/dns-domain-delegation
  Name servers:
  [
  "ns1-02.azure-dns.com.",
  "ns2-02.azure-dns.net.",
  "ns3-02.azure-dns.org.",
  "ns4-02.azure-dns.info."
  ]

Custom DNS alias:
    Resource group: haiche-dns-doc
    WebLogic Server Administration Console URL: http://admin.contoso.com:7001/console
    WebLogic Server Administration Console secured URL: https://admin.contoso.com:7002/console
  

    Application Gateway URL: http://applications.contoso.com:7777
    Application Gateway secured URL: https://applications.contoso.com:4444
```

**Note:** The DNS aliases are not accessible now, you must perform Azure DNS delegation after the deployment. Follow [Delegation of DNS zones with Azure DNS](https://aka.ms/dns-domain-delegation) to complete the Azure DNS delegation.


## Verify the Custom Alias

Access the URL from output to verify if the custom alias works.
