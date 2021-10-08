<!--
Copyright (c) 2021, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
-->

# arm-oraclelinux-wls
# Simple deployment of a Oracle Linux VM with WebLogic Server pre-installed

This template allows us to deploy a simple Oracle Linux VM with WebLogic Server (12.2.1.3.0) pre-installed. 
By default, this template deploys an A3 size VM in the resource group location and return the fully qualified domain name of the VM.

To install WebLogic Server, requires Oracle WebLogic Install kit and Oracle JDK to be downloaded, from OTN Site (https://www.oracle.com/technical-resources/). The OTN site requires the user to accept <a href="https://www.oracle.com/downloads/licenses/standard-license.html">OTN Free Developer License Agreement</a> before downloading any resources. 
So, when this template is run, the user will be required to accept the <a href="https://www.oracle.com/downloads/licenses/standard-license.html">OTN Free Developer License Agreement</a> and also provide OTN credentials (username and password), to download the Oracle WebLogic Install Kit and Oracle JDK.


<h3>Using the template</h3>

<h4>Perform string substitution to generate the necessary artifacts for deployment or uploading to the Azure Cloud Partner Portal</h4>

* Install Apache Maven.  This project uses Apache Maven to do a simple
  string substitution for several required parameters in the templates.
  
* From the top level run `mvn clean install`.

* The templates end up in `arm-oraclelinux-wls/arm-oraclelinux-wls/target/arm`.  Change to that directory to run the templates.

<h4>Once you have performed the string substitution, you can deploy the template via the command line</h4>

**PowerShell** 

*#use this command when you need to create a new resource group for your deployment*

*New-AzResourceGroup -Name &lt;resource-group-name&gt; -Location &lt;resource-group-location&gt; 

*New-AzResourceGroupDeployment -ResourceGroupName &lt;resource-group-name&gt; -TemplateFile mainTemplate.json*

**Command line**

```
az group create --name &lt;resource-group-name&gt; --location &lt;resource-group-location&gt;

az group deployment create --resource-group &lt;resource-group-name&gt; --template-file mainTemplate.json  --parameters @parametersFile.json
```

For example:

```
az group deployment create --resource-group 20191001-01-my-rg --parameters @my-parameters.json --template-file arm-oraclelinux-wls/target/arm/mainTemplate.json
```

If you are new to Azure virtual machines, see:

- [Azure Virtual Machines](https://azure.microsoft.com/services/virtual-machines/).
- [Azure Linux Virtual Machines documentation](https://docs.microsoft.com/azure/virtual-machines/linux/)
- [Azure Windows Virtual Machines documentation](https://docs.microsoft.com/azure/virtual-machines/windows/)
- [Template reference](https://docs.microsoft.com/azure/templates/microsoft.compute/allversions)
- [Quickstart templates](https://azure.microsoft.com/resources/templates/?resourceType=Microsoft.Compute&pageNumber=1&sort=Popular)

If you are new to template deployment, see:

[Azure Resource Manager documentation](https://docs.microsoft.com/azure/azure-resource-manager/)

## Considerations for CI/CD

<h3>Running the tests</h3>

Microsoft provides template validation tests in the Git repo for [azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates/tree/master/test/template-tests).  This project includes a Maven configuration to run those tests against the ARM template.  This is useful when building the template as part of a CI/CD pipeline.

<h4>Preconditions</h4>

The environment running the tests must have the git repo for 
[Azure Quickstart Templates)[https://github.com/Azure/azure-quickstart-templates] checked
out in the expected place, and the necessary PowerShell software installed

1. Make it so the environment that runs `mvn` is able to execute the PowerShell command.

2. Git clone the [Azure Quickstart Templates)[https://github.com/Azure/azure-quickstart-templates] into the top level `target` directory.

<h4>Running the tests</h4>

1. run `mvn install` in the top level directory.  **Do not run `mvn
   clean` as this will delete the directory from step 3 above**
   
2. Change to `arm-oraclelinux-wls` and run `mvn -Dgit.repo=edburns -Ptemplate-validation-tests install`

3. The template validation tests should run.  You must see no failures, signified by lines that start with `[-]`
   tests and some large number of passing tests: `[+]`.
   
4. The zip file to upload to the Cloud Partner Portal is located in the
   target directory.

## Updating the Versions

```
mvn versions:set -DnewVersion=1.0.1 -DoldVersion=* -DgroupId=com.oracle.weblogic.azure -DartifactId=*
```
