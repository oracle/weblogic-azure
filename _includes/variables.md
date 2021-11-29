<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

{% comment %}
Account for variability in the repo paths.
{% endcomment %}

{% assign pageDirName = page.dir | replace: "/", "" %}
{% capture pageDir %}{{ pageDirName }}{% endcapture %}

{% if pageDir contains "admin" %}
  {% capture armTemplateBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForVM}}{{ pageDir }}/src/main/arm/{% endcapture %}
  
  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/
  {% endcomment %}

{% else if %}
  {% capture armTemplateBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForAks}}/src/main/arm/{% endcapture %}
  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-aks/src/main/arm/
  {% endcomment %}
{% else %}
  {% assign repoPrefix = site.data.var.repoPrefix %}
  {% capture armTemplateBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForVM}}{{ pageDir }}{{ repoPrefix }}{{ pageDir }}/src/main/arm/{% endcapture %}
  
  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/
  {% endcomment %}

  {% capture armTemplateDeleteNodeBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForVM}}{{ pageDir }}/deletenode/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-vm/arm-oraclelinux-wls-cluster/deletenode/src/main/
  {% endcomment %}

  {% capture armTemplateAddNodeBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForVM}}{{ pageDir }}/addnode/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-vm/arm-oraclelinux-wls-cluster/addnode/src/main/
  {% endcomment %}

  {% capture armTemplateAddCacheNodeBasePath %}{{ site.data.var.artifactsLocationBase }}/{{ site.data.var.artifactsLocationTag }}/{{site.data.var.artifactsLocationSubPathForVM}}{{ pageDir }}/addnode-coherence/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/galiacheng/weblogic-azure/2021-10-13-01-Q4/weblogic-azure-vm/arm-oraclelinux-wls-cluster/addnode=-coherence/src/main/
  {% endcomment %}
  
{% endif %}
