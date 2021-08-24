{% comment %}
Account for variability in the repo paths.
{% endcomment %}

{% assign pageDirName = page.dir | replace: "/", "" %}
{% capture pageDir %}{{ pageDirName }}{% endcapture %}

{% if pageDir contains "admin" %}
  {% capture armTemplateBasePath %}{{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/src/main/arm/{% endcapture %}
  
  {% comment %}
  something like https://raw.githubusercontent.com/edburns/arm-oraclelinux-wls-admin/2020-06-24-01-Q2/src/main/arm/
  {% endcomment %}
  
{% else %}
  {% assign repoPrefix = site.data.var.repoPrefix %}
  {% capture armTemplateBasePath %}{{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}{{ repoPrefix }}{{ pageDir }}/src/main/arm/{% endcapture %}
  
  {% comment %}
  something like https://raw.githubusercontent.com/edburns/arm-oraclelinux-wls-cluster/2020-06-24-01-Q2/arm-oraclelinux-wls-cluster/src/main/arm/
  {% endcomment %}

  {% capture armTemplateDeleteNodeBasePath %}{{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/deletenode/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/edburns/arm-oraclelinux-wls-cluster/2020-06-24-01-Q2/deletenode/src/main/
  {% endcomment %}

  {% capture armTemplateAddNodeBasePath %}{{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/addnode/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/edburns/arm-oraclelinux-wls-cluster/2020-06-24-01-Q2/addnode/src/main/
  {% endcomment %}

  {% capture armTemplateAddCacheNodeBasePath %}{{ site.data.var.artifactsLocationBase }}{{ pageDir }}/{{ site.data.var.artifactsLocationTag }}/addnode-coherence/src/main/{% endcapture %}

  {% comment %}
  something like https://raw.githubusercontent.com/edburns/arm-oraclelinux-wls-cluster/2020-06-24-01-Q2/addnode=-coherence/src/main/
  {% endcomment %}
  
{% endif %}
