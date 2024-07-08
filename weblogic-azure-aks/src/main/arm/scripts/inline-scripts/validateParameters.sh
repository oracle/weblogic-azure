# Copyright (c) 2021, 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.
#
# env inputs:
# ORACLE_ACCOUNT_NAME
# ORACLE_ACCOUNT_PASSWORD
# ACR_NAME
# AKS_CLUSTER_NAME
# AKS_CLUSTER_RESOURCEGROUP_NAME
# BASE64_FOR_SERVICE_PRINCIPAL
# WLS_SSL_KEYVAULT_NAME
# WLS_SSL_KEYVAULT_RESOURCEGROUP_NAME
# WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME
# WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME
# WLS_SSL_KEYVAULT_IDENTITY_TYPE
# WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME
# WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME
# WLS_SSL_KEYVAULT_TRUST_TYPE
# WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS
# WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD
# WLS_SSL_IDENTITY_DATA
# WLS_SSL_IDENTITY_PASSWORD
# WLS_SSL_IDENTITY_TYPE
# WLS_SSL_TRUST_DATA
# WLS_SSL_TRUST_PASSWORD
# WLS_SSL_TRUST_TYPE
# WLS_SSL_PRIVATE_KEY_ALIAS
# WLS_SSL_PRIVATE_KEY_PASSWORD
# APPLICATION_GATEWAY_SSL_KEYVAULT_NAME
# APPLICATION_GATEWAY_SSL_KEYVAULT_RESOURCEGROUP
# APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME
# APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME
# APPLICATION_GATEWAY_SSL_FRONTEND_CERT_DATA
# APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD
# DNS_ZONE_NAME
# DNS_ZONE_RESOURCEGROUP_NAME
# AKS_VERSION
# USE_AKS_WELL_TESTED_VERSION
# VNET_FOR_APPLICATIONGATEWAY

#Validate teminal status with $?, exit with exception if errors happen.
# $1 - error message
# $2 -  root cause message
function validate_status() {
  if [ $? != 0 ]; then
    echo_stderr "Errors happen during: $1." $2
    exit 1
  else
    echo_stdout "$1"
  fi
}

# Validate compute resources
# Check points:
#   - there is enough resource for AKS cluster
#   - there is enough resource for VM to build the image
# Example to list the vm usage:
# az vm list-usage --location "East US" -o table
# Name                                      CurrentValue    Limit
# ----------------------------------------  --------------  -------
# Availability Sets                         0               2500
# Total Regional vCPUs                      2               200
# Virtual Machines                          1               25000
# Virtual Machine Scale Sets                0               2500
# Dedicated vCPUs                           0               3000
# Cloud Services                            0               2500
# Total Regional Low-priority vCPUs         0               100
# Standard DSv2 Family vCPUs                0               100
# Standard Av2 Family vCPUs                 2               100
# Basic A Family vCPUs                      0               100
# Standard A0-A7 Family vCPUs               0               200
# Standard A8-A11 Family vCPUs              0               100
# Standard D Family vCPUs                   0               100
# Standard Dv2 Family vCPUs                 0               100
# Standard DS Family vCPUs                  0               100
# Standard G Family vCPUs                   0               100
# Standard GS Family vCPUs                  0               100
# Standard F Family vCPUs                   0               100
# Standard FS Family vCPUs                  0               100
# ... ...
function validate_compute_resources() {
  # Resource for ubuntu machine
  # 2 Standard Av2 Family vCPUs

  # query total cores
  local vmUsage=$(az vm list-usage -l ${location} -o json)
  local totalCPUs=$(echo ${vmUsage} | jq '.[] | select(.name.value=="cores") | .limit' | tr -d "\"")
  local currentCPUs=$(echo ${vmUsage} | jq '.[] | select(.name.value=="cores") | .currentValue' | tr -d "\"")
  local aksCPUs=0

  # if creating new AKS cluster
  if [[ "${createAKSCluster,,}" == "true" ]]; then
    local aksVMDetails=$(az vm list-skus --size ${aksAgentPoolVMSize} -l ${location} --query [0])
    local vmFamily=$(echo ${aksVMDetails} | jq '.family' | tr -d "\"")
    local vmCPUs=$(echo ${aksVMDetails} | jq '.capabilities[] | select(.name=="vCPUs") | .value' | tr -d "\"")
    aksCPUs=$((vmCPUs * aksAgentPoolNodeCount))

    # query CPU usage of the vm family
    local familyLimit=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamily}'") | .limit' | tr -d "\"")
    local familyUsage=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamily}'") | .currentValue' | tr -d "\"")
    local requiredFamilyCPUs=$((aksCPUs + familyUsage))
    # make sure thers is enough vCPUs of the family for AKS
    if [ ${requiredFamilyCPUs} -gt ${familyLimit} ]; then
      echo_stderr "It requires ${aksCPUs} ${vmFamily} vCPUs to create the AKS cluster, ${vmFamily} vCPUs quota is limited to ${familyLimit}, current usage is ${familyUsage}."
      exit 1
    fi
  fi

  local vmFamilyOfUbuntu="standardAv2Family"
  local familyLimit=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamilyOfUbuntu}'") | .limit' | tr -d "\"")
  local familyUsage=$(echo ${vmUsage} | jq '.[] | select(.name.value=="'${vmFamilyOfUbuntu}'") | .currentValue' | tr -d "\"")
  local requiredFamilyCPUs=$((2 + familyUsage))
  # make sure thers is enough vCPUs of the family for ubuntu machine
  if [ ${requiredFamilyCPUs} -gt ${familyLimit} ]; then
      echo_stderr "It requires 2 ${vmFamilyOfUbuntu} vCPUs to create an ubuntu machine for docker image, ${vmFamilyOfUbuntu} vCPUs quota is limited to ${familyLimit}, current usage is ${familyUsage}."
      exit 1
  fi

  local requiredCPU=$((aksCPUs + 2 + currentCPUs))
  if [ ${requiredCPU} -gt ${totalCPUs} ]; then
      echo_stderr "It requires ${requiredCPU} vCPUs to run WLS on AKS, vCPUs quota is limited to ${totalCPUs}, current usage is ${currentCPUs}."
      exit 1
  fi

  echo_stdout "Check compute resources: passed!"
}

# Ensure the cluster has enough memory resources.
# The offer deploys a WLS cluster with 1 + ${APP_REPLICAS} pods, each pod requestes 1.5GB and 0.25CPU.
# Minimum memory requirement: 12 + (APP_REPLICAS + 1)*1.5 GB
function validate_memory_resources() {
  if [[ "${createAKSCluster,,}" == "true" ]]; then
    local requiredMemoryinGB=$(echo "12+($APP_REPLICAS+1)*1.5" | bc)

    local vmDetails=$(az vm list-skus --size ${aksAgentPoolVMSize} -l ${location} --query [0])
    validate_status "Query VM details of ${aksAgentPoolVMSize} in ${location}."

    local memoryGB=$(echo ${vmDetails} | jq '.capabilities[] | select(.name=="MemoryGB") | .value' | tr -d "\"")
    local requestedMemory=$(echo "$aksAgentPoolNodeCount*$memoryGB" | bc)
    echo_stdout "Current requested memory is ${requestedMemory}GB."
    if [[ $(echo "${requestedMemory}<${requiredMemoryinGB}" | bc) -eq 1 ]]; then
      echo_stderr "It requires ${requiredMemoryinGB} GiB memory to create the AKS cluster, you have to select a larger VM size or increase node count."
      exit 1
    fi

  fi

  echo_stdout "Check memory resources: passed!"
}

function validate_ocr_account() {
  # install docker cli
  install_docker

  # ORACLE_ACCOUNT_NAME
  # ORACLE_ACCOUNT_PASSWORD
  docker logout
  echo "${ORACLE_ACCOUNT_PASSWORD}" | docker login ${ocrLoginServer} -u ${ORACLE_ACCOUNT_NAME} --password-stdin
  validate_status "login OCR with user ${ORACLE_ACCOUNT_NAME}"

  echo_stdout "Check OCR account: passed!"
}

function check_acr() {
  local ready=false
  local attempt=0
  while [[ "${ready}" == "false" && $attempt -le ${checkAcrMaxAttempt} ]]; do
      echo_stdout "Check if ACR ${ACR_NAME} is ready, attempt: ${attempt}."
      ready=true

      local ret=$(az acr show --name ${ACR_NAME} --resource-group ${ACR_RESOURCE_GROUP})
      if [ -z "${ret}" ]; then
          ready=false
      fi

      attempt=$((attempt + 1))
      sleep ${checkAcrInterval}
  done

  if [ ${attempt} -gt ${checkAcrMaxAttempt} ]; then
      echo_stderr "ACR ${ACR_NAME} is not ready."
      exit 1
  fi

  echo_stdout "Check if ACR ${ACR_NAME} is ready to import image."
}

function validate_ocr_image() {
  local ocrImageFullPath="${ocrLoginServer}/${ocrGaImagePath}:${wlsImageTag}"

  if [[ "${ORACLE_ACCOUNT_ENTITLED,,}" == "true" ]]; then

    # download the ga cpu image mapping file.
    local cpuImagesListFile=weblogic_cpu_images.json
    curl -L "${gitUrl4CpuImages}" --retry ${retryMaxAttempt} -o ${cpuImagesListFile}
    local cpuTag=$(cat ${cpuImagesListFile} | jq ".items[] | select(.gaTag == \"${wlsImageTag}\") | .cpuTag" | tr -d "\"")
    echo_stdout "cpu tag: ${cpuTag}"
    # if we can not find a matched image, keep the input tag.
    if [[ "${cpuTag}" == "" ||  "${cpuTag,,}" == "null" ]]; then
      cpuTag=${wlsImageTag}
    fi

    ocrImageFullPath="${ocrLoginServer}/${ocrCpuImagePath}:${cpuTag}"
  fi

  echo_stdout "image path: ${ocrImageFullPath}"  

  # to mitigate error in https://learn.microsoft.com/en-us/answers/questions/1188413/the-resource-with-name-name-and-type-microsoft-con
  az provider register -n Microsoft.ContainerRegistry

  check_acr

  # validate the image by importing it to ACR.
  # if failure happens, the image should be unavailable
  local tmpImagePath="tmp$(date +%s):${wlsImageTag}"
  az acr import --name ${ACR_NAME} \
    --resource-group ${ACR_RESOURCE_GROUP} \
    --source ${ocrImageFullPath} \
    -u ${ORACLE_ACCOUNT_NAME} \
    -p ${ORACLE_ACCOUNT_PASSWORD} \
    --image ${tmpImagePath} \
    --only-show-errors

  # $? equals 0 even though failure happens.
  # check if the image is imported successfully.
  local ret=$(az acr repository show --name $ACR_NAME --image ${tmpImagePath})
  if [ -n "${ret}" ]; then
    # delete the image from ACR.
    az acr repository delete --name ${ACR_NAME} --image ${tmpImagePath} --yes
  else
    echo_stderr $ret
    echo_stderr ""
    echo_stderr "Image ${ocrImageFullPath} is not available! Please make sure you have accepted the Oracle Standard Terms and Restrictions and the image exists in https://container-registry.oracle.com/ "
    if [[ "${ORACLE_ACCOUNT_ENTITLED,,}" == "true" ]]; then
      echo_stderr "Make sure you are entitled to access middleware/weblogic_cpu repository."
    fi

    exit 1
  fi

  echo_stdout "Check OCR image ${ocrImageFullPath}: passed!"
}

function check_acr_admin_enabled() {
  local acrName=$1
  local acrRgName=$2
  echo_stdout "check if admin user enabled in ACR $acrName "
  local adminUserEnabled=$(az acr show --name $acrName --resource-group ${acrRgName} --query "adminUserEnabled")
  validate_status "query 'adminUserEnabled' property of ACR ${acrName}" "Invalid ACR: ${acrName}"

  if [[ "${adminUserEnabled}" == "false" ]]; then
    echo_stderr "Make sure admin user is enabled in ACR $acrName. Please find steps in https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication?WT.mc_id=Portal-Microsoft_Azure_CreateUIDef&tabs=azure-cli#admin-account"
    exit 1
  fi
}

function validate_acr_image() {
  echo_stdout "user provided ACR: $ACR_NAME_FOR_USER_PROVIDED_IMAGE"

  local pathWithoutTag=${userProvidedImagePath%\:*}
  local repository=${pathWithoutTag#*\/}
  local tag="${userProvidedImagePath##*:}"

  local tagIndex=$(az acr repository show-tags --name $ACR_NAME_FOR_USER_PROVIDED_IMAGE --repository ${repository} | jq 'index("'${tag}'")')
  validate_status "check if tag ${tag} exists." "Invalid image path ${userProvidedImagePath}"
  if [[ "${tagIndex}" == "null" ]]; then
    echo_stderr "Image ${tag} does not exist in ${repository}."
    exit 1
  fi

  echo_stdout "Check ACR image: passed!"
}

function validate_base_image_path() {
  if [[ "${useOracleImage,,}" == "true" ]]; then
    validate_ocr_account
    validate_ocr_image
  else
    validate_acr_image
  fi
}

function validate_acr_admin_enabled()
{
  if [[ "${useOracleImage,,}" == "true" ]]; then
    check_acr_admin_enabled "${ACR_NAME}" "${ACR_RESOURCE_GROUP}"
  else
    check_acr_admin_enabled "${ACR_NAME_FOR_USER_PROVIDED_IMAGE}" "${ACR_RG_NAME_FOR_USER_PROVIDED_IMAGE}"
  fi
}

function download_wls_ssl_certificates_from_keyvault() {
  # check key vault accessibility for template deployment
  local enabledForTemplateDeployment=$(az keyvault show --name ${WLS_SSL_KEYVAULT_NAME} --query "properties.enabledForTemplateDeployment")
  if [[ "${enabledForTemplateDeployment,,}" != "true" ]]; then
    echo_stderr "Make sure Key Vault ${WLS_SSL_KEYVAULT_NAME} is enabled for template deployment. "
    exit 1
  fi

  # allow the identity to access the keyvault
  local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)
  az keyvault set-policy --name ${WLS_SSL_KEYVAULT_NAME}  --object-id ${principalId} --secret-permissions get list
  validate_status "grant identity permission to get/list secrets in key vault ${WLS_SSL_KEYVAULT_NAME}"

  local identityDataFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/identityData.txt
  local identityPswFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/identityPsw.txt
  local trustDataFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/trustData.txt
  local trustPswFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/trustPsw.txt
  local privateKeyAliasFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/privateKeyData.txt
  local privateKeyPswFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/privateKeyPsw.txt

  rm -f ${identityDataFileName}
  rm -f ${identityPswFileName}
  rm -f ${trustDataFileName}
  rm -f ${trustPswFileName}
  rm -f ${privateKeyAliasFileName}
  rm -f ${privateKeyPswFileName}

  # download identity data
  az keyvault secret download --file ${identityDataFileName} \
    --name ${WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set identity data with values in download file
  WLS_SSL_IDENTITY_DATA="$(cat ${identityDataFileName} | base64)"
  # remove the data file
  rm -f ${identityDataFileName}

  # download identity password
  az keyvault secret download --file ${identityPswFileName} \
    --name ${WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set identity psw with values in download file
  WLS_SSL_IDENTITY_PASSWORD="$(cat ${identityPswFileName})"
  # remove the data file
  rm -f ${identityPswFileName}

  # download trust data
  az keyvault secret download --file ${trustDataFileName} \
    --name ${WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set trust data with values in download file
  WLS_SSL_TRUST_DATA="$(cat ${trustDataFileName} | base64)"
  # remove the data file
  rm -f ${trustDataFileName}

  # download trust psw
  az keyvault secret download --file ${trustPswFileName} \
    --name ${WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set trust psw with values in download file
  WLS_SSL_TRUST_PASSWORD="$(cat ${trustPswFileName})"
  # remove the data file
  rm -f ${trustPswFileName}

  # download alias
  az keyvault secret download --file ${privateKeyAliasFileName} \
    --name ${WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set alias with values in download file
  WLS_SSL_PRIVATE_KEY_ALIAS="$(cat ${privateKeyAliasFileName})"
  # remove the data file
  rm -f ${privateKeyAliasFileName}

  # download private key psw
  az keyvault secret download --file ${privateKeyPswFileName} \
    --name ${WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  # set private key psw with values in download file
  WLS_SSL_PRIVATE_KEY_PASSWORD="$(cat ${privateKeyPswFileName})"
  # remove the data file
  rm -f ${privateKeyPswFileName}

  WLS_SSL_IDENTITY_TYPE="${WLS_SSL_KEYVAULT_IDENTITY_TYPE}"
  WLS_SSL_TRUST_TYPE="${WLS_SSL_KEYVAULT_TRUST_TYPE}"

  # reset key vault policy
  az keyvault delete-policy --name ${WLS_SSL_KEYVAULT_NAME}  --object-id ${principalId}
  validate_status "delete identity permission to get/list secrets in key vault ${WLS_SSL_KEYVAULT_NAME}"
}

function validate_wls_ssl_certificates() {
  if [[ "${sslConfigurationAccessOption}" == "${sslCertificateKeyVaultOption}" ]]; then
    download_wls_ssl_certificates_from_keyvault
  fi

  local wlsIdentityKeyStoreFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/identity.keystore
  local wlsTrustKeyStoreFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/trust.keystore
  echo "$WLS_SSL_IDENTITY_DATA" | base64 -d >$wlsIdentityKeyStoreFileName
  echo "$WLS_SSL_TRUST_DATA" | base64 -d >$wlsTrustKeyStoreFileName

  # use default Java, if no, install open jdk 11.
  # why not using Microsoft open jdk? 
  # No apk installation package!
  export JAVA_HOME=/usr/lib/jvm/default-jvm/
  if [ ! -d "${JAVA_HOME}" ]; then
      install_jdk
      JAVA_HOME=/usr/lib/jvm/java-11-openjdk
  fi
  #validate if identity keystore has entry
  ${JAVA_HOME}/bin/keytool -list -v \
      -keystore $wlsIdentityKeyStoreFileName \
      -storepass $WLS_SSL_IDENTITY_PASSWORD \
      -storetype $WLS_SSL_IDENTITY_TYPE |
      grep 'Entry type:' |
      grep 'PrivateKeyEntry'

  validate_status "validate Identity Keystore."

  #validate if trust keystore has entry
  ${JAVA_HOME}/bin/keytool -list -v \
      -keystore ${wlsTrustKeyStoreFileName} \
      -storepass $WLS_SSL_TRUST_PASSWORD \
      -storetype $WLS_SSL_TRUST_TYPE |
      grep 'Entry type:' |
      grep 'trustedCertEntry'

  validate_status "validate Trust Keystore."

  echo_stdout "validate SSL key stores: passed!"
}

function download_application_gateway_certificate_from_keyvault() {
  # check key vault accessibility for template deployment
  local enabledForTemplateDeployment=$(az keyvault show --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} --query "properties.enabledForTemplateDeployment")
  if [[ "${enabledForTemplateDeployment,,}" != "true" ]]; then
    echo_stderr "Make sure Key Vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} is enabled for template deployment. "
    exit 1
  fi

  # allow the identity to access the keyvault
  local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)
  az keyvault set-policy --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}  --object-id ${principalId} --secret-permissions get list
  validate_status "grant identity permission to get/list secrets in key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"

  local gatewayCertDataFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/gatewayCertData.txt
  local gatewayCertPswFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/gatewayCertPsw.txt

  rm -f ${gatewayCertDataFileName}
  rm -f ${gatewayCertPswFileName}

  # download cert data
  az keyvault secret download --file ${gatewayCertDataFileName} \
    --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME} \
    --vault-name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}
  validate_status "download secret ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME} from key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"
  # set cert data with values in download file
  APPLICATION_GATEWAY_SSL_FRONTEND_CERT_DATA=$(cat ${gatewayCertDataFileName})
  # remove the data file
  rm -f ${gatewayCertDataFileName}

  # download cert data
  az keyvault secret download --file ${gatewayCertPswFileName} \
    --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME} \
    --vault-name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} 
  validate_status "download secret ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME} from key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"
  # set cert data with values in download file
  APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD=$(cat ${gatewayCertPswFileName})
  # remove the data file
  rm -f ${gatewayCertPswFileName}

  # reset key vault policy
  az keyvault delete-policy --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}  --object-id ${principalId}
  validate_status "delete identity permission to get/list secrets in key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"
}

function validate_gateway_frontend_certificates() {
  if [[ "${appGatewayCertificateOption}" == "generateCert" ]]; then
    return
  fi

  if [[ "${appGatewayCertificateOption}" == "haveKeyVault" ]]; then
    download_application_gateway_certificate_from_keyvault
  fi

  local appgwFrontCertFileName=${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/gatewaycert.pfx
  echo "$APPLICATION_GATEWAY_SSL_FRONTEND_CERT_DATA" | base64 -d >$appgwFrontCertFileName

  openssl pkcs12 \
    -in $appgwFrontCertFileName \
    -nocerts \
    -out ${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/cert.key \
    -passin pass:${APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD} \
    -passout pass:${APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD}
  
  validate_status "access application gateway frontend key." "Make sure the Application Gateway frontend certificate is correct."
}

function validate_dns_zone() {
  if [[ "${checkDNSZone,,}" == "true" ]]; then
    az network dns zone show -n ${DNS_ZONE_NAME} -g ${DNS_ZONE_RESOURCEGROUP_NAME}
    validate_status "check DNS Zone ${DNS_ZONE_NAME}" "Make sure the DNS Zone exists."

    echo_stdout "Check DNS Zone: passed!"
  fi
}

function get_aks_default_version() {
  constDefaultAKSVersion=$(az aks get-versions --location ${location} \
    | jq '.orchestrators[] | select(.default==true) | .orchestratorVersion' \
    | tr -d "\"")

  validate_status "get AKS default version ${constDefaultAKSVersion}"
}

function validate_aks_version() {
  if [[ "${USE_AKS_WELL_TESTED_VERSION,,}" == "true" ]]; then
    local aksWellTestedVersionFile=aks_well_tested_version.json
    # download the json file that has well-tested version from weblogic-azure repo.
    curl -L "${gitUrl4AksWellTestedVersionJsonFile}" --retry ${retryMaxAttempt} -o ${aksWellTestedVersionFile}
    local aksWellTestedVersion=$(cat ${aksWellTestedVersionFile} | jq  ".value" | tr -d "\"")
    echo "AKS well-tested version: ${aksWellTestedVersion}"
    # check if the well-tested version is supported in the location
    local ret=$(az aks get-versions --location ${location} \
      | jq ".orchestrators[] | select(.orchestratorVersion == \"${aksWellTestedVersion}\") | .orchestratorVersion" \
      | tr -d "\"")
    if [[ "${aksWellTestedVersion}" !=  "" ]] && [[ "${ret}" ==  "${aksWellTestedVersion}" ]]; then
      outputAksVersion=${aksWellTestedVersion}
    else
      # if the well-tested version is invalid, use default version.
      get_aks_default_version
      outputAksVersion=${constDefaultAKSVersion}
    fi
  else
    # check if the input version is supported in the location
    local ret=$(az aks get-versions --location ${location} \
      | jq ".orchestrators[] | select(.orchestratorVersion == \"${AKS_VERSION}\") | .orchestratorVersion" \
      | tr -d "\"")
    if [[ "${ret}" ==  "${AKS_VERSION}" ]]; then
      outputAksVersion=${AKS_VERSION}
    else
      echo_stderr "ERROR: invalid aks version ${AKS_VERSION} in ${location}."
      exit 1
    fi
  fi
}

function enable_aks_managed_identity() {
  local identityLength=$(az aks show -g ${AKS_CLUSTER_RESOURCEGROUP_NAME} -n ${AKS_CLUSTER_NAME} | jq '.identity | length')
  echo "identityLength ${identityLength}"

  if [ $identityLength -lt 1 ]; then
      echo "enable managed identity..."
      # Your cluster is using service principal, and you are going to update the cluster to use systemassigned managed identity.
      # After updating, your cluster's control plane and addon pods will switch to use managed identity, but kubelet will KEEP USING SERVICE PRINCIPAL until you upgrade your agentpool.
      az aks update -y -g ${AKS_CLUSTER_RESOURCEGROUP_NAME} -n ${AKS_CLUSTER_NAME} --enable-managed-identity

      validate_status "Enable Applciation Gateway Ingress Controller for ${AKS_CLUSTER_NAME}."
  fi
}

# VNET input sample:
# {
#     "name": "wlsaks-vnet",
#     "resourceGroup": "haiche-test",
#     "addressPrefixes": [
#         "10.3.0.0/28"
#     ],
#     "addressPrefix": "10.3.0.0/28",
#     "newOrExisting": "new",
#     "subnets": {
#         "gatewaySubnet": {
#             "name": "wls-aks-gateway-subnet",
#             "addressPrefix": "10.3.0.0/29",
#             "startAddress": "10.3.0.4"
#         }
#     }
# }
# To make sure the subnet only have application gateway
function validate_appgateway_vnet() {
  echo_stdout "VNET for application gateway: ${VNET_FOR_APPLICATIONGATEWAY}"
  local vnetName=$(echo ${VNET_FOR_APPLICATIONGATEWAY} | jq '.name' | tr -d "\"")
  local vnetResourceGroup=$(echo ${VNET_FOR_APPLICATIONGATEWAY} | jq '.resourceGroup' | tr -d "\"")
  local newOrExisting=$(echo ${VNET_FOR_APPLICATIONGATEWAY} | jq '.newOrExisting' | tr -d "\"")
  local subnetName=$(echo ${VNET_FOR_APPLICATIONGATEWAY} | jq '.subnets.gatewaySubnet.name' | tr -d "\"")

  if [[ "${newOrExisting,,}" != "new" ]]; then
    # the subnet can only have Application Gateway.
    # query ipConfigurations:
    # if lenght of ipConfigurations is greater than 0, the subnet fails to meet requirement of Application Gateway.
    local ret=$(az network vnet show \
      -g ${vnetResourceGroup} \
      --name ${vnetName} \
      | jq ".subnets[] | select(.name==\"${subnetName}\") | .ipConfigurations | length")
    
    if [ $ret -gt 0 ]; then
      echo_stderr "ERROR: invalid subnet for Application Gateway, the subnet has ${ret} connected device(s). Make sure the subnet is only for Application Gateway."
      exit 1
    fi
  fi
}

function query_available_zones() {
  if [[ "${createAKSCluster,,}" == "true" ]]; then
    outputAvailableZones=$(az vm list-skus -l ${location} --size ${aksAgentPoolVMSize} --zone true | jq -c '.[] | .locationInfo[] | .zones')
  fi

  if [ -z "${outputAvailableZones}" ]; then  
    outputAvailableZones="[]"
  fi  

  export outputAvailableZones="${outputAvailableZones}"
}

function output_result() {
  echo "AKS version: ${outputAksVersion}"
  result=$(jq -n -c \
    --arg aksVersion "$outputAksVersion" \
    --arg agentAvailabilityZones "${outputAvailableZones}" \
    '{aksVersion: $aksVersion, agentAvailabilityZones: $agentAvailabilityZones}')
  echo "result is: $result"
  echo $result >$AZ_SCRIPTS_OUTPUT_PATH
}

# main
location=$1
createAKSCluster=$2
aksAgentPoolVMSize=$3
aksAgentPoolNodeCount=$4
useOracleImage=$5
wlsImageTag=$6
userProvidedImagePath=$7
enableCustomSSL=$8
sslConfigurationAccessOption=$9
appGatewayCertificateOption=${10}
enableAppGWIngress=${11}
checkDNSZone=${12}

outputAksVersion=${constDefaultAKSVersion}
sslCertificateKeyVaultOption="keyVaultStoredConfig"

validate_compute_resources

validate_memory_resources

validate_base_image_path

validate_acr_admin_enabled

if [[ "${enableCustomSSL,,}" == "true" ]]; then
  validate_wls_ssl_certificates
fi

if [[ "${enableAppGWIngress,,}" == "true" ]]; then
  validate_gateway_frontend_certificates
fi

validate_dns_zone

if [[ "${createAKSCluster,,}" == "true" ]]; then
  validate_aks_version
fi

if [[ "${createAKSCluster,,}" != "true" ]]; then
  enable_aks_managed_identity
fi

validate_appgateway_vnet

query_available_zones

output_result

