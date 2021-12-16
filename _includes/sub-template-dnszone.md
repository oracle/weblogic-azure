
<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

### Custom DNS (optional)

#### Registered Domain Name

You need to buy a domain name to create a custom DNS alias.

#### Azure DNS Zone

If you create the DNS alias on an existing [Azure DNS Zone](https://docs.microsoft.com/en-us/azure/dns/dns-overview), make sure you have perfomed the [Azure DNS Delegation](https://docs.microsoft.com/en-us/azure/dns/dns-domain-delegation).  After you have completed the delegation, you can verify it with `nslookup`.  For example, assuming your domain name is **contoso.com**, this output shows a correct delegation.

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

We strongly recommand you create an Azure DNS Zone for domain management and reuse it for other perpose. To create an Azure DNS Zone, follow the steps in [Quickstart: Create an Azure DNS zone and record using the Azure portal](https://docs.microsoft.com/en-us/azure/dns/dns-getstarted-portal).
