We have an [Azure Marketplace offer](https://portal.azure.com/?feature.customPortal=false#create/oracle.20210620-wls-on-aks20210620-wls-on-aks) that 
makes it easy to get started with WebLogic Server on Azure.  For complete documentation on the offer, see [the user guide](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/). 

If you need to go beyond the capabilities of the Azure Marketplace offer, this guidance enables several advanced features.  The following features and more are possible.

- Customize Azure Container Insights with specified retention days, workspace SKU and resource permissions.

- Customize Azure Kubernetes Service version and Agent Pool name.

- Create custom T3 channel for WebLogic Administration Server and cluster and expose the T3 channel via Azure Standard Load Balancer service.

- Customize the CPU and memory resources for server pod. This enables you to go beyond the default values of 200m and 1.5Gi.
