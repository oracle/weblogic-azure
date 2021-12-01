We have [Azure Marketplace offer](https://portal.azure.com/?feature.customPortal=false#create/oracle.20210620-wls-on-aks20210620-wls-on-aks) that 
makes it easy to get started with WebLogic Server on Azure, see [document](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/). 
If you want the following advanced usage, we have mainTemplate which enables you to customize your WebLogic cluster.

- Customize Azure Container Insight with specified retension days, workaspace SKU and resource permissions.

- Customize Azure Kubernetes Service version and Agent Pool name.

- Create custom T3 channel for WebLogic Administration Server and cluster and expose the T3 channel via Azure Standard Load Balancer serive.

- Customize the CPU and memory resource for server pod, which default by 200m and 1.5Gi.