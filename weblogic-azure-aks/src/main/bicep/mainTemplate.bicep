/* 
* Copyright (c) 2021, Oracle Corporation and/or its affiliates.
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
*   $ mvn -Pbicep -Ddev -Passembly clean install
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
@maxLength(12)
@minLength(1)
@description('The name for this node pool. Node pool must contain only lowercase letters and numbers. For Linux node pools the name cannot be longer than 12 characters.')
param aksAgentPoolName string = 'agentpool'
@maxValue(10000)
@minValue(1)
@description('The number of nodes that should be created along with the cluster. You will be able to resize the cluster later.')
param aksAgentPoolNodeCount int = 3
@description('The size of the virtual machines that will form the nodes in the cluster. This cannot be changed after creating the cluster')
param aksAgentPoolVMSize string = 'Standard_DS2_v2'
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
@description('Urls of Java EE application packages.')
param appPackageUrls array = []
@description('The number of managed server to start.')
param appReplicas int = 2
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
])
@description('One of the supported database types')
param databaseType string = 'oracle'
@allowed([
  'createOrUpdate'
  'delete'
])
@description('createOrUpdate: create a new data source connection, or update an existing data source connection. delete: delete an existing data source connection')
param dbConfigurationType string = 'createOrUpdate'
@description('Password for Database')
param dbPassword string = newGuid()
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'wlsgw'
@description('Azure DNS Zone name.')
param dnszoneAdminConsoleLabel string = 'admin'
@description('Specify a label used to generate subdomain of Application Gateway. The final subdomain name will be label.dnszoneName, e.g. applications.contoso.xyz')
param dnszoneAppGatewayLabel string = 'www'
param dnszoneName string = 'contoso.xyz'
param dnszoneRGName string = 'dns-contoso-rg'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:postgresql://contoso.postgres.database.azure.com:5432/postgres'
@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false
@description('In addition to the CPU and memory metrics included in AKS by default, you can enable Container Insights for more comprehensive data on the overall performance and health of your cluster. Billing is based on data ingestion and retention settings.')
param enableAzureMonitoring bool = false
@description('true to create persistent volume using file share.')
param enableAzureFileShare bool = false
@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false
param enableCustomSSL bool = false
param enableDB bool = false
param enableDNSConfiguration bool = false
@description('An user assigned managed identity. Make sure the identity has permission to create/update/delete/list Azure resources.')
param identity object
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
param location string = 'eastus'
@description('Object array to define Load Balancer service, each object must include service name, service target[admin-server or cluster-1], port.')
param lbSvcValues array = []
@description('Name prefix of managed server.')
param managedServerPrefix string = 'managed-server'
@secure()
@description('Password of Oracle SSO account.')
param ocrSSOPSW string
@description('User name of Oracle SSO account.')
param ocrSSOUser string
@secure()
@description('Base64 string of service principal. use the command to generate a testing string: az ad sp create-for-rbac --sdk-auth | base64 -w0')
param servicePrincipal string = newGuid()
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
param sslUploadedCustomIdentityKeyStoreData string = 'null'
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
param sslUploadedCustomTrustKeyStoreData string = 'null'
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
param sslUploadedPrivateKeyAlias string = 'contoso'
@secure()
@description('Password of the private key')
param sslUploadedPrivateKeyPassPhrase string = newGuid()
@description('True to set up internal load balancer service.')
param useInternalLB bool = false
@description('ture to upload Java EE applications and deploy the applications to WebLogic domain.')
param utcValue string = utcNow()
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
@description('Memory requests for admin server and managed server.')
param wlsMemory string = '1.5Gi'
@secure()
param wlsPassword string
@description('User name for WebLogic Administrator.')
param wlsUserName string = 'weblogic'

var const_appGatewaySSLCertOptionHaveCert = 'haveCert'
var const_appGatewaySSLCertOptionHaveKeyVault = 'haveKeyVault'
var const_azureSubjectName = '${format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')}'
var const_hasTags = contains(resourceGroup(), 'tags')
// If there is not tag 'wlsKeyVault' and key vault is created for the following usage:
// * upload custom TLS/SSL certificates for WLS trust and identity.
// * upload custom certificate for gateway frontend TLS/SSL.
// * generate selfsigned certificate for gateway frontend TLS/SSL.
var const_bCreateNewKeyVault = (!const_hasTags || !contains(resourceGroup().tags, name_tagNameForKeyVault) || empty(resourceGroup().tags.wlsKeyVault)) && ((enableCustomSSL && sslConfigurationAccessOption != const_wlsSSLCertOptionKeyVault) || (enableAppGWIngress && (appGatewayCertificateOption != const_appGatewaySSLCertOptionHaveKeyVault)))
var const_bCreateStorageAccount = (createAKSCluster || !const_hasStorageAccount) && const_enablePV
var const_defaultKeystoreType = 'PKCS12'
var const_enableNetworking = (length(lbSvcValues) > 0) || enableAppGWIngress
var const_enablePV = enableCustomSSL || enableAzureFileShare
var const_hasStorageAccount = !createAKSCluster && reference('query-existing-storage-account').outputs.storageAccount.value != 'null'
var const_identityKeyStoreType = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStoreType : sslUploadedCustomIdentityKeyStoreType
var const_keyvaultNameFromTag = const_hasTags && contains(resourceGroup().tags, name_tagNameForKeyVault) ? resourceGroup().tags.wlsKeyVault : ''
var const_trustKeyStoreType = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStoreType : sslUploadedCustomTrustKeyStoreType
var const_wlsSSLCertOptionKeyVault = 'keyVaultStoredConfig'
var name_defaultPidDeployment = 'pid'
var name_dnsNameforApplicationGateway = '${concat(dnsNameforApplicationGateway, take(utcValue, 6))}'
var name_domainLabelforApplicationGateway = '${take(concat(name_dnsNameforApplicationGateway, '-', toLower(resourceGroup().name), '-', toLower(wlsDomainName)), 63)}'
var name_identityKeyStoreDataSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStoreDataSecretName : 'myIdentityKeyStoreData'
var name_identityKeyStorePswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomIdentityKeyStorePassPhraseSecretName : 'myIdentityKeyStorePsw'
var name_keyVaultName = empty(const_keyvaultNameFromTag) ? '${take(concat('wls-kv', uniqueString(utcValue)), 24)}' : resourceGroup().tags.wlsKeyVault
var name_privateKeyAliasSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultPrivateKeyAliasSecretName : 'privateKeyAlias'
var name_privateKeyPswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultPrivateKeyPassPhraseSecretName : 'privateKeyPsw'
var name_rgKeyvaultForWLSSSL = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultResourceGroup : resourceGroup().name
var name_storageAccountName = const_hasStorageAccount ? reference('query-existing-storage-account').outputs.storageAccount.value : 'wls${uniqueString(utcValue)}'
var name_tagNameForKeyVault = 'wlsKeyVault'
var name_tagNameForStorageAccount = 'wlsStorageAccount'
var name_trustKeyStoreDataSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStoreDataSecretName : 'myTrustKeyStoreData'
var name_trustKeyStorePswSecret = (sslConfigurationAccessOption == const_wlsSSLCertOptionKeyVault) ? sslKeyVaultCustomTrustKeyStorePassPhraseSecretName : 'myTrustKeyStorePsw'
var ref_wlsDomainDeployment = reference(resourceId('Microsoft.Resources/deployments', (enableCustomSSL) ? 'setup-wls-cluster-with-custom-ssl-enabled' : 'setup-wls-cluster'))
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

module wlsSSLCertSecretsDeployment 'modules/_azure-resoruces/_keyvault/_keyvaultForWLSSSLCert.bicep' = if (enableCustomSSL && sslConfigurationAccessOption != const_wlsSSLCertOptionKeyVault) {
  name: 'upload-wls-ssl-cert-to-keyvault'
  params: {
    keyVaultName: name_keyVaultName
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
    pids
  ]
}

// get key vault object in a resource group
resource sslKeyvault 'Microsoft.KeyVault/vaults@2019-09-01' existing = if (enableCustomSSL) {
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
    identity: identity
    wlsDomainUID: wlsDomainUID
  }
}

module wlsDomainDeployment 'modules/setupWebLogicCluster.bicep' = if (!enableCustomSSL) {
  name: 'setup-wls-cluster'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.wlsAKSEnd == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSEnd
    _pidStart: pids.outputs.wlsAKSStart == '' ? name_defaultPidDeployment : pids.outputs.wlsAKSStart
    aciResourcePermissions: aciResourcePermissions
    aciRetentionInDays: aciRetentionInDays
    aciWorkspaceSku: aciWorkspaceSku
    acrName: acrName
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolVMSize: aksAgentPoolVMSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: aksVersion
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    createACR: createACR
    createAKSCluster: createAKSCluster
    createStorageAccount: const_bCreateStorageAccount
    enableAzureMonitoring: enableAzureMonitoring
    enableCustomSSL: enableCustomSSL
    enablePV: const_enablePV
    identity: identity
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    storageAccountName: name_storageAccountName
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: sslUploadedCustomIdentityKeyStoreData
    wlsIdentityKeyStorePassphrase: sslUploadedCustomIdentityKeyStorePassphrase
    wlsIdentityKeyStoreType: const_defaultKeystoreType
    wlsImageTag: wlsImageTag
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
    pids
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
    acrName: acrName
    aksAgentPoolName: aksAgentPoolName
    aksAgentPoolNodeCount: aksAgentPoolNodeCount
    aksAgentPoolVMSize: aksAgentPoolVMSize
    aksClusterNamePrefix: aksClusterNamePrefix
    aksClusterRGName: aksClusterRGName
    aksClusterName: aksClusterName
    aksVersion: aksVersion
    appPackageUrls: appPackageUrls
    appReplicas: appReplicas
    createACR: createACR
    createAKSCluster: createAKSCluster
    createStorageAccount: const_bCreateStorageAccount
    enableAzureMonitoring: enableAzureMonitoring
    enableCustomSSL: enableCustomSSL
    enablePV: const_enablePV
    identity: identity
    location: location
    managedServerPrefix: managedServerPrefix
    ocrSSOPSW: ocrSSOPSW
    ocrSSOUser: ocrSSOUser
    storageAccountName: name_storageAccountName
    wdtRuntimePassword: wdtRuntimePassword
    wlsClusterSize: wlsClusterSize
    wlsCPU: wlsCPU
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
    wlsIdentityKeyStoreData: sslKeyvault.getSecret(name_identityKeyStoreDataSecret)
    wlsIdentityKeyStorePassphrase: sslKeyvault.getSecret(name_identityKeyStorePswSecret)
    wlsIdentityKeyStoreType: const_identityKeyStoreType
    wlsImageTag: wlsImageTag
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

module appgwSecretDeployment 'modules/_azure-resoruces/_keyvaultForGateway.bicep' = if (enableAppGWIngress && (appGatewayCertificateOption != const_appGatewaySSLCertOptionHaveKeyVault)) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    backendCertificateDataValue: appGatewaySSLBackendRootCertData
    certificateDataValue: appGatewaySSLCertData
    certificatePasswordValue: appGatewaySSLCertPassword
    enableCustomSSL: enableCustomSSL
    identity: identity
    sku: keyVaultSku
    subjectName: format('CN={0}', enableDNSConfiguration ? format('{0}.{1}', dnsNameforApplicationGateway, dnszoneName) : const_azureSubjectName)
    useExistingAppGatewaySSLCertificate: (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveCert) ? true : false
    keyVaultName: name_keyVaultName
  }
  dependsOn: [
    wlsDomainDeployment
    wlsDomainWithCustomSSLDeployment
  ]
}

/*
 * Update tags to save key vault name and storage account name that are used for current configuration
*/
resource applyTags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  properties: {
    tags: {
      '${name_tagNameForKeyVault}': const_bCreateNewKeyVault ? name_keyVaultName : const_keyvaultNameFromTag
      '${name_tagNameForStorageAccount}': (const_bCreateStorageAccount || const_hasStorageAccount) ? name_storageAccountName : ''
    }
  }
  dependsOn: [
    appgwSecretDeployment
  ]
}

module networkingDeployment 'modules/networking.bicep' = if (const_enableNetworking) {
  name: 'networking-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidNetworkingEnd: pids.outputs.networkingEnd == '' ? name_defaultPidDeployment : pids.outputs.networkingEnd
    _pidNetworkingStart: pids.outputs.networkingStart == '' ? name_defaultPidDeployment : pids.outputs.networkingStart
    _pidAppgwEnd: pids.outputs.appgwEnd == '' ? name_defaultPidDeployment : pids.outputs.appgwEnd
    _pidAppgwStart: pids.outputs.appgwStart == '' ? name_defaultPidDeployment : pids.outputs.appgwStart
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName.value
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName.value
    appGatewayCertificateOption: appGatewayCertificateOption
    appGatewayPublicIPAddressName: appGatewayPublicIPAddressName
    appgwForAdminServer: appgwForAdminServer
    appgwForRemoteConsole: appgwForRemoteConsole
    createDNSZone: createDNSZone
    dnsNameforApplicationGateway: name_domainLabelforApplicationGateway
    dnszoneAdminConsoleLabel: dnszoneAdminConsoleLabel
    dnszoneAppGatewayLabel: dnszoneAppGatewayLabel
    dnszoneName: dnszoneName
    dnszoneRGName: dnszoneRGName
    enableAppGWIngress: enableAppGWIngress
    enableCookieBasedAffinity: enableCookieBasedAffinity
    enableCustomSSL: enableCustomSSL
    enableDNSConfiguration: enableDNSConfiguration
    identity: identity
    keyVaultName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultName : appgwSecretDeployment.outputs.keyVaultName
    keyVaultResourceGroup: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultResourceGroup : resourceGroup().name
    keyvaultBackendCertDataSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLBackendRootCertDataSecretName : appgwSecretDeployment.outputs.sslBackendCertDataSecretName
    keyVaultSSLCertDataSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLCertDataSecretName : appgwSecretDeployment.outputs.sslCertDataSecretName
    keyVaultSSLCertPasswordSecretName: (!enableAppGWIngress || (appGatewayCertificateOption == const_appGatewaySSLCertOptionHaveKeyVault)) ? keyVaultSSLCertPasswordSecretName : appgwSecretDeployment.outputs.sslCertPwdSecretName
    location: location
    lbSvcValues: lbSvcValues
    servicePrincipal: servicePrincipal
    useInternalLB: useInternalLB
    wlsDomainName: wlsDomainName
    wlsDomainUID: wlsDomainUID
  }
  dependsOn: [
    appgwSecretDeployment
  ]
}

module datasourceDeployment 'modules/_setupDBConnection.bicep' = if (enableDB) {
  name: 'datasource-deployment'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    _pidEnd: pids.outputs.dbEnd
    _pidStart: pids.outputs.dbStart
    aksClusterRGName: ref_wlsDomainDeployment.outputs.aksClusterRGName.value
    aksClusterName: ref_wlsDomainDeployment.outputs.aksClusterName.value
    databaseType: databaseType
    dbConfigurationType: dbConfigurationType
    dbPassword: dbPassword
    dbUser: dbUser
    dsConnectionURL: dsConnectionURL
    identity: identity
    jdbcDataSourceName: jdbcDataSourceName
    wlsDomainUID: wlsDomainUID
    wlsPassword: wlsPassword
    wlsUserName: wlsUserName
  }
  dependsOn: [
    networkingDeployment
  ]
}

output aksClusterName string = ref_wlsDomainDeployment.outputs.aksClusterName.value
output adminConsoleInternalUrl string = ref_wlsDomainDeployment.outputs.adminServerUrl.value
output adminConsoleExternalUrl string = const_enableNetworking ? networkingDeployment.outputs.adminConsoleExternalUrl : ''
output adminConsoleExternalSecuredUrl string = const_enableNetworking ? networkingDeployment.outputs.adminConsoleExternalSecuredUrl : ''
// If TLS/SSL enabled, only secured url is working, will not output HTTP url.
output adminRemoteConsoleUrl string = const_enableNetworking && !enableCustomSSL ? networkingDeployment.outputs.adminRemoteConsoleUrl: ''
output adminRemoteConsoleSecuredUrl string = const_enableNetworking ? networkingDeployment.outputs.adminRemoteConsoleSecuredUrl: ''
output clusterInternalUrl string = ref_wlsDomainDeployment.outputs.clusterSVCUrl.value
output clusterExternalUrl string = const_enableNetworking ? networkingDeployment.outputs.clusterExternalUrl : ''
output clusterExternalSecuredUrl string = const_enableNetworking ? networkingDeployment.outputs.clusterExternalSecuredUrl : ''
