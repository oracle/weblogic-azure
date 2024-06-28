/* 
* Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
* Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
*
* Terms:
* aci is short for Azure Container Insight
* aks is short for Azure Kubernetes Service
* acr is short for Azure Container Registry
*
* Run the template:
*   $ bicep build mainTemplate.bicep
*   $ az deployment group create -f mainTemplate.json -g <rg-name>
*
* Build marketplace offer for test:
*   Replace the partner center pid in mainTemplate.bicep, then run the following command to generate the ARM package, and upload it to partner center.
*   If using azure-javaee-iaas-parent less than 1.0.13, use:
*     $ mvn -Pbicep -Passembly -Ddev clean install
*   otherwise, use
*     $ mvn -Pbicep-dev -Passembly clean install
*/

param _artifactsLocation string = deployment().properties.templateLink.uri
@secure()
param _artifactsLocationSasToken string = ''
@description('true to use resource or workspace permissions. false to require workspace permissions.')
param aciResourcePermissions bool = true
@description('Number of days to retain data in Azure Monitor workspace.')
param aciRetentionInDays int = 120
@description('Pricing tier: PerGB2018 or legacy tiers (Free, Standalone, PerNode, Standard or Premium) which are not available to all customers.')
param aciWorkspaceSku string = 'pergb2018'
param acrName string = 'acr-contoso'
param acrResourceGroupName string = 'acr-contoso-rg'
@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
@description('Set the minimum node count for the cluster.')
param aksAgentPoolNodeCount int = 3
@maxValue(1000)
@minValue(3)
@description('Set the maximum node count for the cluster.')
param aksAgentPoolNodeMaxCount int = 5
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param vmSize string = 'Standard_DS2_v2'
@description('Prefix for cluster name. Only The name can contain only letters, numbers, underscores and hyphens. The name must start with letter or number.')
param aksClusterNamePrefix string = 'wlsonaks'
@description('Resource group name of an existing AKS cluster.')
param aksClusterRGName string = 'aks-contoso-rg'
@description('Name of an existing AKS cluster.')
param aksClusterName string = 'aks-contoso'
@description('The AKS version.')
param aksVersion string = 'default'
@allowed([
  'haveCert'
  'haveKeyVault'
  'generateCert'
])
@description('Three scenarios we support for deploying app gateway')
param appGatewayCertificateOption string = 'haveCert'
@description('Public IP Name for the Application Gateway')
param appGatewayPublicIPAddressName string = 'gwip'
@description('The one-line, base64 string of the backend SSL root certificate data.')
param appGatewaySSLBackendRootCertData string = 'appgw-ssl-backend-data'
@description('The one-line, base64 string of the SSL certificate data.')
param appGatewaySSLCertData string = 'appgw-ssl-data'
@secure()
@description('The value of the password for the SSL Certificate')
param appGatewaySSLCertPassword string = newGuid()
@description('Create Application Gateway ingress for admin console.')
param appgwForAdminServer bool = true
@description('Create Application Gateway ingress for remote console.')
param appgwForRemoteConsole bool = true
@description('If true, configure Azure Application Gateway frontend IP with private IP.')
param appgwUsePrivateIP bool = false
@description('Urls of Java EE application packages.')
param appPackageUrls array = []
@description('The number of managed server to start.')
param appReplicas int = 2
@description('Scale up once average cpu utilization is larger then the input number ')
param averageCpuUtilization int = 60
@description('Scale up once average memory utilization is larger then the input number ')
param averageMemoryUtilization int = 60
@description('true to create a new Azure Container Registry.')
param createACR bool = false
@description('true to create a new AKS cluster.')
param createAKSCluster bool = true
@description('If true, the template will update records to the existing DNS Zone. If false, the template will create a new DNS Zone.')
param createDNSZone bool = false
@allowed([
  'oracle'
  'postgresql'
  'sqlserver'
  'mysql'
  'otherdb'
])
@description('One of the supported database types')
param databaseType string = 'oracle'
@allowed([
  'createOrUpdate'
  'delete'
])
@description('createOrUpdate: create a new data source connection, or update an existing data source connection. delete: delete an existing data source connection')
param dbConfigurationType string = 'createOrUpdate'
@description('Urls of datasource drivers, must be specified if database type is otherdb')
param dbDriverLibrariesUrls array = []
@description('Datasource driver name, must be specified if database type is otherdb')
param dbDriverName string = 'org.contoso.Driver'
@description('Determines the transaction protocol (global transaction processing behavior) for the data source.')
param dbGlobalTranPro string = 'EmulateTwoPhaseCommit'
@description('Managed identity that has access to database')
param dbIdentity object = {}
@secure()
@description('Password for Database')
param dbPassword string = newGuid()
@description('The name of the database table to use when testing physical database connections. This name is required when you specify a Test Frequency and enable Test Reserved Connections.')
param dbTestTableName string = 'Null'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'wlsgw'
@description('Specify a label used to generate subdomain of Admin server. The final subdomain name will be label.dnszoneName, e.g. admin.contoso.xyz')
param dnszoneAdminConsoleLabel string = 'admin'
@description('Specify a label used to generate subdomain of Admin server T3 channel. The final subdomain name will be label.dnszoneName, e.g. admin-t3.contoso.xyz')
param dnszoneAdminT3ChannelLabel string = 'admin-t3'
@description('Specify a label used to generate subdomain of WebLogic cluster. The final subdomain name will be label.dnszoneName, e.g. applications.contoso.xyz')
param dnszoneClusterLabel string = 'www'
param dnszoneClusterT3ChannelLabel string = 'cluster-t3'
@description('Azure DNS Zone name.')
param dnszoneName string = 'contoso.xyz'
param dnszoneRGName string = 'dns-contoso-rg'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database.azure.com:5432/postgres'
@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false
@description('true to enable Horizontal Autoscaling.')
param enableAutoscaling bool = false
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('true to create persistent volume using file share.')
param enableAzureFileShare bool = false
@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDB bool = false
param enableDNSConfiguration bool = false
@description('Configure a custom channel in Admin Server for the T3 protocol that enables HTTP tunneling')
param enableAdminT3Tunneling bool = false
@description('Configure a custom channel in WebLogic cluster for the T3 protocol that enables HTTP tunneling')
param enableClusterT3Tunneling bool = false
@description('Enable passwordless datasource connection.')
param enablePswlessConnection bool = false
@allowed([
  'cpu'
  'memory'
])
param hpaScaleType string = 'cpu'
@description('Is the specified SSO account associated with an active Oracle support contract?')
param isSSOSupportEntitled bool = false
@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceName string = 'jdbc/contoso'
@description('Existing Key Vault Name')
param keyVaultName string = 'kv-contoso'
@description('Resource group name in current subscription containing the KeyVault')
param keyVaultResourceGroup string = 'kv-contoso-rg'
@description('Price tier for Key Vault.')
param keyVaultSku string = 'Standard'
@description('The name of the secret in the specified KeyVault whose value is the SSL Root Certificate Data for Appliation Gateway backend TLS/SSL.')
param keyVaultSSLBackendRootCertDataSecretName string = 'kv-ssl-backend-data'
@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data for Appliation Gateway frontend TLS/SSL.')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'
@description('The name of the secret in the specified KeyVault whose value is the password for the SSL Certificate of Appliation Gateway frontend TLS/SSL')
param keyVaultSSLCertPasswordSecretName string = 'kv-ssl-psw'
param location string
@description('Object array to define Load Balancer service, each object must include service name, service target[admin-server or cluster-1], port.')
param lbSvcValues array = []
@description('Name prefix of managed server.')
param managedServerPrefix string = 'managed-server'
@description('To mitigate ARM-TTK error: Control Named vnetForApplicationGateway must output the newOrExisting property when hideExisting is false')
param newOrExistingVnetForApplicationGateway string = 'new'
@secure()
@description('Password of Oracle SSO account.')
param ocrSSOPSW string = newGuid()
@description('User name of Oracle SSO account.')
param ocrSSOUser string = 'null'
@allowed([
  'uploadConfig'
  'keyVaultStoredConfig'
])
@description('Two scenarios to refer to WebLogic Server TLS/SSL certificates.')
param sslConfigurationAccessOption string = 'uploadConfig'
@description('Secret name in KeyVault containing Weblogic Custom Identity Keystore Data')
param sslKeyVaultCustomIdentityKeyStoreDataSecretName string = 'kv-wls-identity-data'
@description('Secret name in KeyVault containing Weblogic Custom Identity Keystore Passphrase')
param sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName string = 'kv-wls-identity-psw'
@description('Weblogic Custom Identity Keystore type')
@allowed([
  'JKS'
  'PKCS12'
])
param sslKeyVaultCustomIdentityKeyStoreType string = 'PKCS12'
@description('Secret name in KeyVault containing Weblogic Custom Trust Store Data')
param sslKeyVaultCustomTrustKeyStoreDataSecretName string = 'kv-wls-trust-data'
@description('Secret name in KeyVault containing Weblogic Custom Trust Store Passphrase')
param sslKeyVaultCustomTrustKeyStorePassPhraseSecretName string = 'kv-wls-trust-psw'
@description('WWeblogic Custom Trust Store type')
@allowed([
  'JKS'
  'PKCS12'
])
param sslKeyVaultCustomTrustKeyStoreType string = 'PKCS12'
@description('Resource group containing Weblogic SSL certificates')
param sslKeyVaultName string = 'kv-wls-ssl-name'
@description('Secret name in KeyVault containing Weblogic Server private key alias')
param sslKeyVaultPrivateKeyAliasSecretName string = 'contoso'
@description('Secret name in KeyVault containing Weblogic Server private key passphrase')
param sslKeyVaultPrivateKeyPassPhraseSecretName string = 'kv-wls-ssl-alias'
@description('Keyvault name containing Weblogic SSL certificates')
param sslKeyVaultResourceGroup string = 'rg-kv-wls-ssl-name'
@description('Custom Identity Store Data')
@secure()
param sslUploadedCustomIdentityKeyStoreData string = newGuid()
@secure()
@description('Custom Identity Store passphrase')
param sslUploadedCustomIdentityKeyStorePassphrase string = newGuid()
@description('Weblogic Custom Identity Store Type')
@allowed([
  'JKS'
  'PKCS12'
])
param sslUploadedCustomIdentityKeyStoreType string = 'PKCS12'
@description('Custom Trust Store data')
@secure()
param sslUploadedCustomTrustKeyStoreData string = newGuid()
@secure()
@description('Custom Trust Store passphrase')
param sslUploadedCustomTrustKeyStorePassPhrase string = newGuid()
@description('Weblogic Custom Trust Store Type')
@allowed([
  'JKS'
  'PKCS12'
])
param sslUploadedCustomTrustKeyStoreType string = 'PKCS12'
@description('Alias of the private key')
@secure()
param sslUploadedPrivateKeyAlias string = newGuid()
@secure()
@description('Password of the private key')
param sslUploadedPrivateKeyPassPhrase string = newGuid()
@description('Public port of the custom T3 channel in admin server')
param t3ChannelAdminPort int = 7005
@description('Public port of the custom T3 channel in WebLoigc cluster')
param t3ChannelClusterPort int = 8011
@description('True to use latest supported Kubernetes version.')
param useLatestSupportedAksVersion bool = true
@description('True to enable HPA for auto scaling.')
param useHpa bool = true
@description('True to set up internal load balancer service.')
param useInternalLB bool = false
@description('ture to upload Java EE applications and deploy the applications to WebLogic domain.')
param utcValue string = utcNow()
@description('User provided ACR for base image')
param userProvidedAcr string = 'null'
param userProvidedAcrRgName string = 'null'
@description('User provided base image path')
param userProvidedImagePath string = 'null'
@description('Use Oracle images or user provided patched images')
param useOracleImage bool = true
param validateApplications bool = false
@description('VNET for Application Gateway.')
param vnetForApplicationGateway object = {
  name: 'wlsaks-app-gateway-vnet'
  resourceGroup: resourceGroup().name
  addressPrefixes: [
    '172.16.0.0/24'
  ]
  addressPrefix: '172.16.0.0/24'
  newOrExisting: 'new'
  subnets: {
    gatewaySubnet: {
      name: 'wlsaks-gateway-subnet'
      addressPrefix: '172.16.0.0/24'
      startAddress: '172.16.0.4'
    }
  }
}
@description('To mitigate ARM-TTK error: Control Named vnetForApplicationGateway must output the resourceGroup property when hideExisting is false')
param vnetRGNameForApplicationGateway string = 'vnet-contoso-rg-name'
@secure()
@description('Password for model WebLogic Deploy Tooling runtime encrytion.')
param wdtRuntimePassword string
@description('Maximum cluster size.')
param wlsClusterSize int = 5
@description('Requests for CPU resources for admin server and managed server.')
param wlsCPU string = '200m'
@description('Name of WebLogic domain to create.')
param wlsDomainName string = 'domain1'
@description('UID of WebLogic domain, used in WebLogic Operator.')
param wlsDomainUID string = 'sample-domain1'
@description('Docker tag that comes after "container-registry.oracle.com/middleware/weblogic:"')
param wlsImageTag string = '12.2.1.4'
param wlsJavaOption string = 'null'
@description('Memory requests for admin server and managed server.')
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

// To mitigate arm-ttk error: Type Mismatch: Parameter in nested template is defined as string, but the parent template defines it as bool.
var _enableCustomSSL = enableCustomSSL
var _enableAppGWIngress = enableAppGWIngress
var _useExistingAppGatewaySSLCertificate = (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveCert) ? true : false

var const_appGatewaySSLCertOptionHaveCert = 'haveCert'
var const_appGatewaySSLCertOptionHaveKeyVault = 'haveKeyVault'
var const_azcliVersion = '2.53.0'
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var const_bCreateStorageAccount = (createAKSCluster || !const_hasStorageAccount) && const_enablePV
var const_bValidateApplications= validateApplications && (length(appPackageUrls) > 0)
var const_createNewAcr = useOracleImage && createACR
var const_defaultKeystoreType = 'PKCS12'
var const_enableNetworking = (length(lbSvcValues) > 0) || enableAppGWIngress
var const_enablePV = enableCustomSSL || enableAzureFileShare
var const_hasStorageAccount = !createAKSCluster && queryStorageAccount.outputs.storageAccount != 'null'
var const_identityKeyStoreType = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStoreType : sslUploadedCustomIdentityKeyStoreType
var const_showAdminConsoleExUrl = (length(lbSvcValues) > 0) || (enableAppGWIngress && appgwForAdminServer)
var const_showRemoteAdminConsoleExUrl = ((length(lbSvcValues) > 0) || (enableAppGWIngress && appgwForRemoteConsole)) && !enableCustomSSL
var const_showRemoteAdminConsoleSecuredExUrl = ((length(lbSvcValues) > 0) || (enableAppGWIngress && appgwForRemoteConsole)) && enableCustomSSL
var const_trustKeyStoreType = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStoreType : sslUploadedCustomTrustKeyStoreType
var const_wlsClusterName = 'cluster-1'
var const_wlsJavaOptions = wlsJavaOption == '' ? 'null' : wlsJavaOption
var const_wlsSSLCertOptionKeyVault = 'keyVaultStoredConfig'
var name_appgwFrontendSSLCertName = 'appGatewaySslCert'
var name_appgwBackendRootCertName = 'appGatewayTrustedRootCert'
var name_defaultPidDeployment = 'pid'
var name_dnsNameforApplicationGateway = '${dnsNameforApplicationGateway}${take(utcValue, 6)}'
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}-${toLower(wlsDomainName)}', 63)
var name_identityKeyStoreDataSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStoreDataSecretName : 'myIdentityKeyStoreData'
var name_identityKeyStorePswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName : 'myIdentityKeyStorePsw'
var name_keyVaultName = '${take('wls-kv${uniqueString(utcValue)}', 24)}'
var name_privateKeyAliasSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultPrivateKeyAliasSecretName : 'privateKeyAlias'
var name_privateKeyPswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultPrivateKeyPassPhraseSecretName : 'privateKeyPsw'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_rgKeyvaultForWLSSSL = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultResourceGroup : resourceGroup().name
var name_storageAccountName = const_hasStorageAccount ? queryStorageAccount.outputs.storageAccount : 'wls${uniqueString(utcValue)}'
var name_trustKeyStoreDataSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStoreDataSecretName : 'myTrustKeyStoreData'
var name_trustKeyStorePswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStorePassPhraseSecretName : 'myTrustKeyStorePsw'
var ref_wlsDomainDeployment = _enableCustomSSL ? wlsDomainWithCustomSSLDeployment : wlsDomainDeployment
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}

/*
* Beginning of the offer deployment
*/
module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

// Due to lack of preprocessor solution for the way we use bicep, must hard-code the pid here.
// For test, replace the pid with testing one, and build the package.
module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-a1775ed4-512c-4cfa-9e68-f0b09b36de90-partnercenter'
}

module uamiDeployment 'modules/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

/*
* Deploy ACR
*/
module preAzureResourceDeployment './modules/_preDeployedAzureResources.bicep' = {
  name: 'prerequisite-resources-deployment'
  params: {
    acrName: acrName
    acrResourceGroupName: acrResourceGroupName
    createNewAcr: const_createNewAcr
    location: location
  }
}

module validateInputs 'modules/_deployment-scripts/_ds-validate-parameters.bicep' = {
  name: 'validate-parameters-and-fail-fast'
  params: {
    acrName: preAzureResourceDeployment.outputs.acrName
    acrResourceGroupName: preAzureResourceDeployment.outputs.acrResourceGroupName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolVMSize: vmSize
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: aksVersion
    appGatewayCertificateOption: appGatewayCertificateOption
    appGatewaySSLCertData: appGatewaySSLCertData
    appGatewaySSLCertPassword: appGatewaySSLCertPassword
    appReplicas: appReplicas
    azCliVersion: const_azcliVersion
    createAKSCluster: createAKSCluster
    createDNSZone: createDNSZone
    dnszoneName: dnszoneName
    dnszoneRGName: dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCustomSSL: enableCustomSSL
    enableDNSConfiguration: enableDNSConfiguration
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroup
    keyVaultSSLCertDataSecretName: keyVaultSSLCertDataSecretName
    keyVaultSSLCertPasswordSecretName: keyVaultSSLCertPasswordSecretName
    identity: obj_uamiForDeploymentScript
    isSSOSupportEntitled: isSSOSupportEntitled
    location: location
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    sslConfigurationAccessOption: sslConfigurationAccessOption
    sslKeyVaultCustomIdentityKeyStoreDataSecretName: sslKeyVaultCustomIdentityKeyStoreDataSecretName
    sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName: sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName
    sslKeyVaultCustomIdentityKeyStoreType: sslKeyVaultCustomIdentityKeyStoreType
    sslKeyVaultCustomTrustKeyStoreDataSecretName: sslKeyVaultCustomTrustKeyStoreDataSecretName
    sslKeyVaultCustomTrustKeyStorePassPhraseSecretName: sslKeyVaultCustomTrustKeyStorePassPhraseSecretName
    sslKeyVaultCustomTrustKeyStoreType: sslKeyVaultCustomTrustKeyStoreType
    sslKeyVaultName: sslKeyVaultName
    sslKeyVaultPrivateKeyAliasSecretName: sslKeyVaultPrivateKeyAliasSecretName
    sslKeyVaultPrivateKeyPassPhraseSecretName: sslKeyVaultPrivateKeyPassPhraseSecretName
    sslKeyVaultResourceGroup: sslKeyVaultResourceGroup
    sslUploadedCustomIdentityKeyStoreData: sslUploadedCustomIdentityKeyStoreData
    sslUploadedCustomIdentityKeyStorePassphrase: sslUploadedCustomIdentityKeyStorePassphrase
    sslUploadedCustomIdentityKeyStoreType: sslUploadedCustomIdentityKeyStoreType
    sslUploadedCustomTrustKeyStoreData: sslUploadedCustomTrustKeyStoreData
    sslUploadedCustomTrustKeyStorePassPhrase: sslUploadedCustomTrustKeyStorePassPhrase
    sslUploadedCustomTrustKeyStoreType: sslUploadedCustomTrustKeyStoreType
    sslUploadedPrivateKeyAlias: sslUploadedPrivateKeyAlias
    sslUploadedPrivateKeyPassPhrase: sslUploadedPrivateKeyPassPhrase
    useAksWellTestedVersion: useLatestSupportedAksVersion
    userProvidedAcr: userProvidedAcr // used in user provided images
    userProvidedAcrRgName: userProvidedAcrRgName
    userProvidedImagePath: userProvidedImagePath
    useOracleImage: useOracleImage
    vnetForApplicationGateway: vnetForApplicationGateway
    wlsImageTag: wlsImageTag
  }
  dependsOn: [
    pids
    preAzureResourceDeployment
    uamiDeployment
  ]
}

module wlsSSLCertSecretsDeployment 'modules/_azure-resoruces/_keyvault/_keyvaultForWLSSSLCert.bicep' = if (enableCustomSSL && sslConfigurationAccessOption != const_wlsSSLCertOptionKeyVault) {
  name: 'upload-wls-ssl-cert-to-keyvault'
  params: {
    keyVaultName: name_keyVaultName
    location: location
    sku: keyVaultSku
    wlsIdentityKeyStoreData: sslUploadedCustomIdentityKeyStoreData
    wlsIdentityKeyStoreDataSecretName: name_identityKeyStoreDataSecret
    wlsIdentityKeyStorePassphrase: sslUploadedCustomIdentityKeyStorePassphrase
    wlsIdentityKeyStorePassphraseSecretName: name_identityKeyStorePswSecret
    wlsPrivateKeyAlias: sslUploadedPrivateKeyAlias
    wlsPrivateKeyAliasSecretName: name_privateKeyAliasSecret
    wlsPrivateKeyPassPhrase: sslUploadedPrivateKeyPassPhrase
    wlsPrivateKeyPassPhraseSecretName: name_privateKeyPswSecret
    wlsTrustKeyStoreData: sslUploadedCustomTrustKeyStoreData
    wlsTrustKeyStoreDataSecretName: name_trustKeyStoreDataSecret
    wlsTrustKeyStorePassPhrase: sslUploadedCustomTrustKeyStorePassPhrase
    wlsTrustKeyStorePassPhraseSecretName: name_trustKeyStorePswSecret
  }
  dependsOn: [
    validateInputs
  ]
}

// get key vault object in a resource group
resource sslKeyvault 'Microsoft.KeyVault/vaults@${azure.apiVersionForKeyVault}' existing = if (enableCustomSSL) {
  name: (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultName : name_keyVaultName
  scope: resourceGroup(name_rgKeyvaultForWLSSSL)
}

// If updating an existing aks cluster, query the storage account that is being used.
// Return "null" is no storage account is applied.
module queryStorageAccount 'modules/_deployment-scripts/_ds-query-storage-account.bicep' = if (!createAKSCluster) {
  name: 'query-existing-storage-account'
  params: {
    aksClusterName: aksClusterName
    aksClusterRGName: aksClusterRGName
    azCliVersion: const_azcliVersion
    identity: obj_uamiForDeploymentScript
    location: location
  }
}

module appgwSecretDeployment 'modules/_azure-resoruces/_keyvaultForGateway.bicep' = if (enableAppGWIngress && (appGatewayCertificateOption != const_appGatewaySSLCertOptionHaveKeyVault)) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    backendCertificateDataValue: appGatewaySSLBackendRootCertData
    certificateDataValue: appGatewaySSLCertData
    certificatePasswordValue: appGatewaySSLCertPassword
    enableCustomSSL: enableCustomSSL
    identity: obj_uamiForDeploymentScript
    location: location
    sku: keyVaultSku
    subjectName: format('CN={0}', enableDNSConfiguration ? format('{0}.{1}', dnsNameforApplicationGateway, dnszoneName) : const_azureSubjectName)
    useExistingAppGatewaySSLCertificate: _useExistingAppGatewaySSLCertificate
    keyVaultName: name_keyVaultName
  }
  dependsOn: [
    wlsSSLCertSecretsDeployment
  ]
}

// To void space overlap with AKS Vnet, must deploy the Applciation Gateway VNet before AKS deployment.
module appgatewayDeployment 'modules/_appGateway.bicep' = if (enableAppGWIngress) {
  name: 'application-gateway-deployment'
  params: {
    _pidAppgwEnd: pids.outputs.appgwEnd == '' ? name_defaultPidDeployment : pids.outputs.appgwEnd
    _pidAppgwStart: pids.outputs.appgwStart == '' ? name_defaultPidDeployment : pids.outputs.appgwStart
    _pidAppgwWithCustomCert: pids.outputs.customCertForAppgw == '' ? name_defaultPidDeployment : pids.outputs.customCertForAppgw
    appgwPublicIPAddressName: appGatewayPublicIPAddressName
    appgwUsePrivateIP: appgwUsePrivateIP
    appgwSslCertName: name_appgwFrontendSSLCertName
    appgwTrustedRootCertName: name_appgwBackendRootCertName
    azCliVersion: const_azcliVersion
    dnsNameforApplicationGateway: name_domainLabelforApplicationGateway
    enableCustomSSL: enableCustomSSL
    identity: obj_uamiForDeploymentScript
    keyVaultName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultName : appgwSecretDeployment.outputs.keyVaultName
    keyVaultResourceGroup: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultResourceGroup : resourceGroup().name
    keyvaultBackendCertDataSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLBackendRootCertDataSecretName : appgwSecretDeployment.outputs.sslBackendCertDataSecretName
    keyvaultFrontendCertDataSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLCertDataSecretName : appgwSecretDeployment.outputs.sslCertDataSecretName
    keyvaultFrontendCertPswSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLCertPasswordSecretName : appgwSecretDeployment.outputs.sslCertPwdSecretName
    location: location
    newOrExistingVnetForApplicationGateway: newOrExistingVnetForApplicationGateway
    vnetForApplicationGateway: vnetForApplicationGateway
    vnetRGNameForApplicationGateway: vnetRGNameForApplicationGateway
  }
  dependsOn: [
    appgwSecretDeployment
  ]
}

module wlsDomainDeployment 'modules/setupWebLogicCluster.bicep' = if (!enableCustomSSL) {
  name: 'setup-wls-cluster'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.wlsAKSEnd == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSEnd
    _pidSSLEnd: pids.outputs.sslEnd == '' ? name_defaultPidDeployment : pids.outputs.sslEnd
    _pidSSLStart: pids.outputs.sslStart == '' ? name_defaultPidDeployment : pids.outputs.sslStart
    _pidStart: pids.outputs.wlsAKSStart == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSStart
    aciResourcePermissions: aciResourcePermissions
    aciRetentionInDays: aciRetentionInDays
    aciWorkspaceSku: aciWorkspaceSku
    acrName: preAzureResourceDeployment.outputs.acrName
    acrResourceGroupName: preAzureResourceDeployment.outputs.acrResourceGroupName
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolNodeMaxCount: aksAgentPoolNodeMaxCount
    vmSize: vmSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: validateInputs.outputs.aksVersion
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    azCliVersion: const_azcliVersion
    createAKSCluster: createAKSCluster
    createStorageAccount: const_bCreateStorageAccount
    databaseType: databaseType
    dbDriverLibrariesUrls: dbDriverLibrariesUrls
    enableAzureMonitoring: enableAzureMonitoring
    enableCustomSSL: enableCustomSSL
    enableAdminT3Tunneling: enableAdminT3Tunneling
    enableClusterT3Tunneling: enableClusterT3Tunneling
    enablePswlessConnection: enablePswlessConnection
    enablePV: const_enablePV
    identity: obj_uamiForDeploymentScript
    isSSOSupportEntitled: isSSOSupportEntitled
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    storageAccountName: name_storageAccountName
    t3ChannelAdminPort: t3ChannelAdminPort
    t3ChannelClusterPort: t3ChannelClusterPort
    wdtRuntimePassword: wdtRuntimePassword
    userProvidedAcr: userProvidedAcr
    userProvidedAcrRgName: userProvidedAcrRgName
    userProvidedImagePath: userProvidedImagePath
    useOracleImage: useOracleImage
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: sslUploadedCustomIdentityKeyStoreData
    wlsIdentityKeyStorePassphrase: sslUploadedCustomIdentityKeyStorePassphrase
    wlsIdentityKeyStoreType: const_defaultKeystoreType
    wlsImageTag: wlsImageTag
    wlsJavaOption: const_wlsJavaOptions
    wlsMemory: wlsMemory
    wlsPassword: wlsPassword
    wlsPrivateKeyAlias: sslUploadedPrivateKeyAlias
    wlsPrivateKeyPassPhrase: sslUploadedPrivateKeyPassPhrase
    wlsTrustKeyStoreData: sslUploadedCustomTrustKeyStoreData
    wlsTrustKeyStorePassPhrase: sslUploadedCustomTrustKeyStorePassPhrase
    wlsTrustKeyStoreType: const_defaultKeystoreType
    wlsUserName: wlsUserName
  }
  dependsOn: [
    validateInputs
    queryStorageAccount
  ]
}

module wlsDomainWithCustomSSLDeployment 'modules/setupWebLogicCluster.bicep' = if (enableCustomSSL) {
  name: 'setup-wls-cluster-with-custom-ssl-enabled'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.wlsAKSEnd == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSEnd
    _pidStart: pids.outputs.wlsAKSStart == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSStart
    aciResourcePermissions: aciResourcePermissions
    aciRetentionInDays: aciRetentionInDays
    aciWorkspaceSku: aciWorkspaceSku
    acrName: preAzureResourceDeployment.outputs.acrName
    acrResourceGroupName: preAzureResourceDeployment.outputs.acrResourceGroupName
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolNodeMaxCount: aksAgentPoolNodeMaxCount
    vmSize: vmSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: validateInputs.outputs.aksVersion
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    azCliVersion: const_azcliVersion
    createAKSCluster: createAKSCluster
    createStorageAccount: const_bCreateStorageAccount
    databaseType: databaseType
    dbDriverLibrariesUrls: dbDriverLibrariesUrls
    enableAzureMonitoring: enableAzureMonitoring
    enableCustomSSL: enableCustomSSL
    enableAdminT3Tunneling: enableAdminT3Tunneling
    enableClusterT3Tunneling: enableClusterT3Tunneling
    enablePswlessConnection: enablePswlessConnection
    enablePV: const_enablePV
    identity: obj_uamiForDeploymentScript
    isSSOSupportEntitled: isSSOSupportEntitled
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    storageAccountName: name_storageAccountName
    t3ChannelAdminPort: t3ChannelAdminPort
    t3ChannelClusterPort: t3ChannelClusterPort
    userProvidedAcr: userProvidedAcr
    userProvidedAcrRgName: userProvidedAcrRgName
    userProvidedImagePath: userProvidedImagePath
    useOracleImage: useOracleImage
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: sslKeyvault.getSecret(name_identityKeyStoreDataSecret)
    wlsIdentityKeyStorePassphrase: sslKeyvault.getSecret(name_identityKeyStorePswSecret)
    wlsIdentityKeyStoreType: const_identityKeyStoreType
    wlsImageTag: wlsImageTag
    wlsJavaOption: const_wlsJavaOptions
    wlsMemory: wlsMemory
    wlsPassword: wlsPassword
    wlsPrivateKeyAlias: sslKeyvault.getSecret(name_privateKeyAliasSecret)
    wlsPrivateKeyPassPhrase: sslKeyvault.getSecret(name_privateKeyPswSecret)
    wlsTrustKeyStoreData: sslKeyvault.getSecret(name_trustKeyStoreDataSecret)
    wlsTrustKeyStorePassPhrase: sslKeyvault.getSecret(name_trustKeyStorePswSecret)
    wlsTrustKeyStoreType: const_trustKeyStoreType
    wlsUserName: wlsUserName
  }
  dependsOn: [
    wlsSSLCertSecretsDeployment
    queryStorageAccount
  ]
}

module networkingDeployment 'modules/networking.bicep' = if (const_enableNetworking) {
  name: 'networking-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidNetworkingEnd: pids.outputs.networkingEnd == '' ? name_defaultPidDeployment : pids.outputs.networkingEnd
    _pidNetworkingStart: pids.outputs.networkingStart == '' ? name_defaultPidDeployment : pids.outputs.networkingStart
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    appGatewayName: _enableAppGWIngress ? appgatewayDeployment.outputs.appGatewayName : ''
    appGatewayAlias: _enableAppGWIngress ? appgatewayDeployment.outputs.appGatewayAlias : ''
    appGatewaySecuredURL: _enableAppGWIngress ? appgatewayDeployment.outputs.appGatewaySecuredURL : ''
    appGatewayURL: _enableAppGWIngress ? appgatewayDeployment.outputs.appGatewayURL : ''
    appGatewaySslCert: name_appgwFrontendSSLCertName
    appGatewayTrustedRootCert: name_appgwBackendRootCertName
    appgwUsePrivateIP: appgwUsePrivateIP
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    azCliVersion: const_azcliVersion
    createAKSCluster: createAKSCluster
    createDNSZone: createDNSZone
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAdminT3ChannelLabel: dnszoneAdminT3ChannelLabel
    dnszoneClusterLabel: dnszoneClusterLabel
    dnszoneClusterT3ChannelLabel: dnszoneClusterT3ChannelLabel
    dnszoneName: dnszoneName
    dnszoneRGName: dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCookieBasedAffinity: enableCookieBasedAffinity
    enableCustomSSL: enableCustomSSL
    enableDNSConfiguration: enableDNSConfiguration
    identity: obj_uamiForDeploymentScript
    location: location
    lbSvcValues: lbSvcValues
    useInternalLB: useInternalLB
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    appgatewayDeployment
    wlsDomainDeployment
    wlsDomainWithCustomSSLDeployment
  ]
}

module datasourceDeployment 'modules/_setupDBConnection.bicep' = if (enableDB && !enablePswlessConnection) {
  name: 'datasource-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.dbEnd
    _pidStart: pids.outputs.dbStart
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    azCliVersion: const_azcliVersion
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbDriverName: dbDriverName
    dbGlobalTranPro: dbGlobalTranPro
    dbPassword: dbPassword
    dbTestTableName: dbTestTableName
    dbUser: dbUser
    dsConnectionURL: dsConnectionURL
    identity: obj_uamiForDeploymentScript
    jdbcDataSourceName: jdbcDataSourceName
    location: location
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    networkingDeployment
  ]
}

module passwordlessDatasourceDeployment 'modules/_setupPasswordlessDBConnection.bicep' = if (enableDB && enablePswlessConnection) {
  name: 'passwordless-datasource-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.pswlessDbEnd
    _pidStart: pids.outputs.pswlessDbStart
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    aksNodeRGName: ref_wlsDomainDeployment.outputs.aksNodeRgName
    azCliVersion: const_azcliVersion
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbGlobalTranPro: dbGlobalTranPro
    dbUser: dbUser
    dbIdentity: dbIdentity
    dsConnectionURL: dsConnectionURL
    identity: obj_uamiForDeploymentScript
    jdbcDataSourceName: jdbcDataSourceName
    location: location
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    networkingDeployment
  ]
}

/*
* To check if all the applciations in WLS cluster become ACTIVE state after all configurations are completed.
* This should be the last step.
*/
module validateApplciations 'modules/_deployment-scripts/_ds-validate-applications.bicep' = if (const_bValidateApplications) {
  name: 'validate-wls-application-status'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    azCliVersion: const_azcliVersion
    identity: obj_uamiForDeploymentScript
    location: location
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    datasourceDeployment
    passwordlessDatasourceDeployment
  ]
}

module horizontalAutoscaling 'modules/_enableAutoScaling.bicep' = if (enableAutoscaling) {
  name: 'enable-horizontal-autoscaling'
  params: {
    _pidCPUUtilization: pids.outputs.cpuUtilization
    _pidEnd: pids.outputs.autoScalingEnd
    _pidMemoryUtilization: pids.outputs.memoryUtilization
    _pidStart: pids.outputs.autoScalingStart
    _pidWme: pids.outputs.enableWlsMonitoringExporter
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    azCliVersion: const_azcliVersion
    hpaScaleType: hpaScaleType
    identity: obj_uamiForDeploymentScript
    location: location
    useHpa: useHpa
    utilizationPercentage: hpaScaleType == 'cpu' ? averageCpuUtilization : averageMemoryUtilization
    wlsClusterSize: wlsClusterSize
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName

  }
  dependsOn: [
    validateApplciations
  ]
}
 
/*
* Query and output WebLogic domain configuration, including: 
*   - domain deployment description
*   - image model
*   - image properties
*/
module queryWLSDomainConfig 'modules/_deployment-scripts/_ds-output-domain-configurations.bicep' = {
  name: 'query-wls-domain-configurations'
  params: {
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName
    azCliVersion: const_azcliVersion
    identity: obj_uamiForDeploymentScript
    location: location
    wlsClusterName: const_wlsClusterName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    horizontalAutoscaling
  ]
}

output aksClusterName string = ref_wlsDomainDeployment.outputs.aksClusterName
output adminConsoleInternalUrl string = ref_wlsDomainDeployment.outputs.adminServerEndpoint
output adminConsoleExternalUrl string = const_showAdminConsoleExUrl ? networkingDeployment.outputs.adminConsoleExternalEndpoint : ''
output adminConsoleExternalSecuredUrl string = const_showAdminConsoleExUrl ? networkingDeployment.outputs.adminConsoleExternalSecuredEndpoint : ''
// If TLS/SSL enabled, only secured url is working, will not output HTTP url.
output adminRemoteConsoleUrl string = const_showRemoteAdminConsoleExUrl ? networkingDeployment.outputs.adminRemoteConsoleEndpoint : ''
output adminRemoteConsoleSecuredUrl string = const_showRemoteAdminConsoleSecuredExUrl ? networkingDeployment.outputs.adminRemoteConsoleSecuredEndpoint : ''
output adminServerT3InternalUrl string = ref_wlsDomainDeployment.outputs.adminServerT3InternalEndpoint
output adminServerT3ExternalUrl string = enableAdminT3Tunneling && const_enableNetworking ? networkingDeployment.outputs.adminServerT3ChannelEndpoint : ''
output clusterInternalUrl string = ref_wlsDomainDeployment.outputs.clusterEndpoint
output clusterExternalUrl string = const_enableNetworking ? networkingDeployment.outputs.clusterExternalEndpoint : ''
output clusterExternalSecuredUrl string = const_enableNetworking ? networkingDeployment.outputs.clusterExternalSecuredEndpoint : ''
output clusterT3InternalUrl string = ref_wlsDomainDeployment.outputs.clusterT3InternalEndpoint
output clusterT3ExternalEndpoint string = enableClusterT3Tunneling && const_enableNetworking ? networkingDeployment.outputs.clusterT3ChannelEndpoint : ''
output kedaScalerServerAddress string = enableAutoscaling ? horizontalAutoscaling.outputs.kedaScalerServerAddress : ''
output shellCmdtoConnectAks string = format('az account set --subscription {0}; az aks get-credentials --resource-group {1} --name {2}', split(subscription().id, '/')[2], ref_wlsDomainDeployment.outputs.aksClusterRGName, ref_wlsDomainDeployment.outputs.aksClusterName)
output shellCmdtoOutputKedaScalerSample string = enableAutoscaling ? horizontalAutoscaling.outputs.base64ofKedaScalerSample : ''
output shellCmdtoOutputWlsDomainYaml string = queryWLSDomainConfig.outputs.shellCmdtoOutputWlsDomainYaml
output shellCmdtoOutputWlsImageModelYaml string = queryWLSDomainConfig.outputs.shellCmdtoOutputWlsImageModelYaml
output shellCmdtoOutputWlsImageProperties string = queryWLSDomainConfig.outputs.shellCmdtoOutputWlsImageProperties
output shellCmdtoOutputWlsVersionsandPatches string = queryWLSDomainConfig.outputs.shellCmdtoOutputWlsVersions
