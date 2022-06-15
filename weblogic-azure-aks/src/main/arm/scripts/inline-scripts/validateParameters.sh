# Copyright (c) 2021, Oracle Corporation and/or its affiliates.
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
# DNA_ZONE_NAME
# DNA_ZONE_RESOURCEGROUP_NAME
# AKS_VERSION
# USE_AKS_WELL_TESTED_VERSION

function echo_stderr() {
  echo "$@" 1>&2
  # The function is used for scripts running within Azure Deployment Script
  # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
  echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/errors.log
}

function echo_stdout() {
  echo "$@"
  # The function is used for scripts running within Azure Deployment Script
  # The value of AZ_SCRIPTS_OUTPUT_PATH is /mnt/azscripts/azscriptoutput
  echo -e "$@" >>${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/debug.log
}

function install_jdk() {
    # Install Microsoft OpenJDK
    apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

    echo "java version"
    java -version
    if [ $? -eq 1 ]; then
        echo_stderr "Failed to install open jdk 11."
        exit 1
    fi
    # JAVA_HOME=/usr/lib/jvm/java-11-openjdk
}

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

# Validate User Assigned Managed Identity
# Check points:
#   - the identity is User Assigned Identity, if not, exit with error.
#   - the identity is assigned with Contributor or Owner role, if not, exit with error.
function validate_user_assigned_managed_identity() {
  # AZ_SCRIPTS_USER_ASSIGNED_IDENTITY
  local uamiType=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "type" -o tsv)
  validate_status "query resource type of ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}" "The user managed identity may not exist, please check."
  if [[ "${uamiType}" != "${userManagedIdentityType}" ]]; then
    echo_stderr "You must use User Assigned Managed Identity, please follow the document to create one: https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal?WT.mc_id=Portal-Microsoft_Azure_CreateUIDef"
  fi

  echo_stdout "query principal Id of the User Assigned Identity."
  local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)

  echo_stdout "check if the user assigned managed identity has Contributor or Owner role."
  local roleLength=$(az role assignment list --assignee ${principalId} |
    jq '[.[] | select(.roleDefinitionName=="Contributor" or .roleDefinitionName=="Owner")] | length')
  if [ ${roleLength} -lt 1 ]; then
    echo_stderr "You must grant the User Assigned Managed Identity with at least Contributor role. Please check ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY}"
  fi

  echo_stdout "Check User Assigned Identity: passed!"
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

function validate_ocr_account() {
  # install docker cli
  apk add docker --no-cache --quiet
  docker --help
  validate_status "install docker"

  # ORACLE_ACCOUNT_NAME
  # ORACLE_ACCOUNT_PASSWORD
  docker logout
  echo "${ORACLE_ACCOUNT_PASSWORD}" | docker login ${ocrLoginServer} -u ${ORACLE_ACCOUNT_NAME} --password-stdin
  validate_status "login OCR with user ${ORACLE_ACCOUNT_NAME}"

  echo_stdout "Check OCR account: passed!"
}

function validate_ocr_image() {
  local ocrImageFullPath="${ocrLoginServer}/${ocrGaImagePath}:${wlsImageTag}"

  if [[ "${ORACLE_ACCOUNT_ENTITLED,,}" == "true" ]]; then

    # download the ga cpu image mapping file.
    local cpuImagesListFile=weblogic_cpu_images.json
    curl -L "${gitUrl4CpuImages}" -o ${cpuImagesListFile}
    local cpuTag=$(cat ${cpuImagesListFile} | jq ".items[] | select(.gaTag == \"${wlsImageTag}\") | .cpuTag" | tr -d "\"")
    echo_stdout "cpu tag: ${cpuTag}"
    # if we can not find a matched image, keep the input tag.
    if [[ "${cpuTag}" == "" ||  "${cpuTag,,}" == "null" ]]; then
      cpuTag=${wlsImageTag}
    fi

    ocrImageFullPath="${ocrLoginServer}/${ocrCpuImagePath}:${cpuTag}"
  fi

  echo_stdout "image path: ${ocrImageFullPath}"

  # validate the image by importing it to ACR.
  # if failure happens, the image should be unavailable
  local tmpImagePath="tmp$(date +%s):${wlsImageTag}"
  az acr import --name ${ACR_NAME} \
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
  local acrName = $1
  echo_stdout "check if admin user enabled in ACR $acrName "
  local adminUserEnabled=$(az acr show --name $acrName --query "adminUserEnabled")
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
    check_acr_admin_enabled ${ACR_NAME}
  else
    check_acr_admin_enabled ${ACR_NAME_FOR_USER_PROVIDED_IMAGE}
  fi
}

# Only support kubenet currently
function validate_aks_network_plugin() {
  # AKS_CLUSTER_NAME
  # AKS_CLUSTER_RESOURCEGROUP_NAME

  if [[ "${createAKSCluster,,}" == "false" ]]; then
    local networkPlugin=$(az aks show -n ${AKS_CLUSTER_NAME} \
      -g ${AKS_CLUSTER_RESOURCEGROUP_NAME} \
      --query 'networkProfile.networkPlugin' -o tsv)

    if [[ "${networkPlugin}" != "kubenet" ]]; then
      echo_stderr "The offer only supports AKS network type kubenet, you are using a cluster of CNI."
      exit 1
    fi
  fi

  echo_stdout "Check AKS networking: passed!"
}

function get_wls_ssl_certificates_from_keyvault() {
  # check key vault accessibility for template deployment
  local enabledForTemplateDeployment=$(az keyvault show --name ${WLS_SSL_KEYVAULT_NAME} --query "properties.enabledForTemplateDeployment")
  if [[ "${enabledForTemplateDeployment,,}" != "true" ]]; then
    echo_stderr "Make sure Key Vault ${WLS_SSL_KEYVAULT_NAME} is enabled for template deployment. "
    exit 1
  fi

  # allow the identity to access the keyvault
  local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)
  az keyvault set-policy --name ${WLS_SSL_KEYVAULT_NAME}  --object-id ${principalId} --secret-permissions get
  validate_status "grant identity permission to get secrets in key vault ${WLS_SSL_KEYVAULT_NAME}"

  # get identity data and set it to the environment variable
  WLS_SSL_IDENTITY_DATA=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_IDENTITY_DATA_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"

  # get identity password and set it to the environment variable
  WLS_SSL_IDENTITY_PASSWORD=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_IDENTITY_PASSWORD_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"
  
  # get trust data and set it to the environment variable
  WLS_SSL_TRUST_DATA=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_TRUST_DATA_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"

  # get trust psw and set it to the environment variable
  WLS_SSL_TRUST_PASSWORD=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_TRUST_PASSWORD_SECRET_NAME} from key vault ${WLS_SSL_KEYVAULT_NAME}"

  # get alias and set it to the environment variable
  WLS_SSL_PRIVATE_KEY_ALIAS=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_PRIVATE_KEY_ALIAS} from key vault ${WLS_SSL_KEYVAULT_NAME}"

  # get private key psw and set it to the environment variable
  WLS_SSL_PRIVATE_KEY_PASSWORD=$(az keyvault secret show \
    --name ${WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD} \
    --vault-name ${WLS_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${WLS_SSL_KEYVAULT_PRIVATE_KEY_PASSWORD} from key vault ${WLS_SSL_KEYVAULT_NAME}"

  WLS_SSL_IDENTITY_TYPE=${WLS_SSL_KEYVAULT_IDENTITY_TYPE}
  WLS_SSL_TRUST_TYPE=${WLS_SSL_KEYVAULT_TRUST_TYPE}

  # reset key vault policy
  az keyvault delete-policy --name ${WLS_SSL_KEYVAULT_NAME}  --object-id ${principalId}
  validate_status "delete identity permission to get secrets in key vault ${WLS_SSL_KEYVAULT_NAME}"
}

function validate_wls_ssl_certificates() {
  if [[ "${sslConfigurationAccessOption}" == "${sslCertificateKeyVaultOption}" ]]; then
    get_wls_ssl_certificates_from_keyvault
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

function get_application_gateway_certificate_from_keyvault() {
  # check key vault accessibility for template deployment
  local enabledForTemplateDeployment=$(az keyvault show --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} --query "properties.enabledForTemplateDeployment")
  if [[ "${enabledForTemplateDeployment,,}" != "true" ]]; then
    echo_stderr "Make sure Key Vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} is enabled for template deployment. "
    exit 1
  fi

  # allow the identity to access the keyvault
  local principalId=$(az identity show --ids ${AZ_SCRIPTS_USER_ASSIGNED_IDENTITY} --query "principalId" -o tsv)
  az keyvault set-policy --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}  --object-id ${principalId} --secret-permissions get
  validate_status "grant identity permission to get secrets in key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"

  # get cert data and set it to the environment variable
  APPLICATION_GATEWAY_SSL_FRONTEND_CERT_DATA=$(az keyvault secret show \
    --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME} \
    --vault-name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_DATA_SECRET_NAME} from key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"

  # get cert password and set it to the environment variable
  APPLICATION_GATEWAY_SSL_FRONTEND_CERT_PASSWORD=$(az keyvault secret show \
    --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME} \
    --vault-name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME} --query value --output tsv)
  validate_status "get secret ${APPLICATION_GATEWAY_SSL_KEYVAULT_FRONTEND_CERT_PASSWORD_SECRET_NAME} from key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"

  # reset key vault policy
  az keyvault delete-policy --name ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}  --object-id ${principalId}
  validate_status "delete identity permission to get secrets in key vault ${APPLICATION_GATEWAY_SSL_KEYVAULT_NAME}"
}

function validate_gateway_frontend_certificates() {
  if [[ "${appGatewayCertificateOption}" == "generateCert" ]]; then
    return
  fi

  if [[ "${appGatewayCertificateOption}" == "haveKeyVault" ]]; then
    get_application_gateway_certificate_from_keyvault
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

function validate_service_principal() {
  local spObject=$(echo "${BASE64_FOR_SERVICE_PRINCIPAL}" | base64 -d)
  validate_status "decode the service principal base64 string." "Invalid service principal."

  # for sdk format string
  # {
  #   "clientId": "3082055e-dd40-452d-9190-xxxxxxx",
  #   "clientSecret": "uh0sZPoNsLKyUU3iOO1~xxxxxxx",
  #   "subscriptionId": "260524c9-7a4d-4483-8d85-xxxxxxx",
  #   "tenantId": "814a03f9-f7c3-41a4-8ecc-xxxxxxx",
  #   "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  #   "resourceManagerEndpointUrl": "https://management.azure.com/",
  #   "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  #   "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  #   "galleryEndpointUrl": "https://gallery.azure.com/",
  #   "managementEndpointUrl": "https://management.core.windows.net/"
  # }
  local principalId=$(echo ${spObject} | jq '.clientId')
  validate_status "get client id from the service principal." "Invalid service principal."

  if [[ "${principalId}" == "null" ]] || [[ "${principalId}" == "" ]]; then
    echo_stderr "the service principal is invalid."
    exit 1
  fi

  echo_stdout "check if the service principal has Contributor or Owner role."
  local roleLength=$(az role assignment list --assignee ${principalId} |
    jq '[.[] | select(.roleDefinitionName=="Contributor" or .roleDefinitionName=="Owner")] | length')
  
  # skip error like: 
  #    Cannot find user or service principal in graph database for '"3082055e-dd40-452d-9190-xxxxxxx"'. 
  #    If the assignee is an appId, make sure the corresponding service principal is created with 'az ad sp create --id "3082055e-dd40-452d-9190-xxxxxxx"'.
  local re='^[0-9]+$'
  if ! [[ $roleLength =~ $re ]] ; then
    echo_stderr "You must grant the service principal with at least Contributor role."
  fi

  if [ ${roleLength} -lt 1 ]; then
    echo_stderr "You must grant the service principal with at least Contributor role."
  fi

  echo_stdout "Check service principal: passed!"
}

function validate_dns_zone() {
  if [[ "${checkDNSZone,,}" == "true" ]]; then
    az network dns zone show -n ${DNA_ZONE_NAME} -g ${DNA_ZONE_RESOURCEGROUP_NAME}
    validate_status "check DNS Zone ${DNA_ZONE_NAME}" "Make sure the DNS Zone exists."

    echo_stdout "Check DNS Zone: passed!"
  fi
}

function validate_aks_version() {
  if [[ "${USE_AKS_WELL_TESTED_VERSION,,}" == "true" ]]; then
    local aksWellTestedVersionFile=aks_well_tested_version.json
    # download the json file that has well-tested version from weblogic-azure repo.
    curl -L "${gitUrl4AksWellTestedVersionJsonFile}" -o ${aksWellTestedVersionFile}
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

function output_result() {
  echo "AKS version: ${outputAksVersion}"
  result=$(jq -n -c \
    --arg aksVersion "$outputAksVersion" \
    '{aksVersion: $aksVersion}')
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
userManagedIdentityType="Microsoft.ManagedIdentity/userAssignedIdentities"

validate_user_assigned_managed_identity

validate_compute_resources

validate_base_image_path

validate_acr_admin_enabled

validate_aks_network_plugin

if [[ "${enableCustomSSL,,}" == "true" ]]; then
  validate_wls_ssl_certificates
fi

if [[ "${enableAppGWIngress,,}" == "true" ]]; then
  validate_gateway_frontend_certificates
  validate_service_principal
fi

validate_dns_zone

if [[ "${createAKSCluster,,}" == "true" ]]; then
  validate_aks_version
fi

output_result

