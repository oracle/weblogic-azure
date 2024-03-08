#!/usr/bin/env bash
################################################
# This script is invoked by a human who:
# - has done az login.
# - can create repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
#
# This script initializes the repo from which this file is was cloned
# with the necessary secrets to run the workflows.
#
# Script design taken from https://github.com/microsoft/NubesGen.
#
################################################

################################################
# Set environment variables - the main variables you might want to configure.
#
AKS_REPO_USER_NAME=oracle
DB_PASSWORD="Secret123!"
# Three letters to disambiguate names.
DISAMBIG_PREFIX=
# The location of the resource group. For example `eastus`. Leave blank to use your default location.
LOCATION=
ORC_SSOPSW=
ORC_SSOUSER=
OWNER_REPONAME=
SLEEP_VALUE=30s
WDT_RUNTIMEPSW=
WLS_PSW=${WDT_RUNTIMEPSW}
WLS_USERNAME=weblogic

# End set environment variables
################################################


set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

read -r -p "Enter a disambiguation prefix (try initials with a sequence number, such as ejb01): " DISAMBIG_PREFIX

if [ "$DISAMBIG_PREFIX" == '' ] ; then
    msg "${RED}You must enter a disambiguation prefix."
    exit 1;
fi

# get ORC_SSOUSER if not set at the beginning of this file
if [ "$ORC_SSOUSER" == '' ] ; then
    read -r -p "Enter Oracle single sign-on userid: " ORC_SSOUSER
fi

# get ORC_SSOPSW if not set at the beginning of this file
if [ "$ORC_SSOPSW" == '' ] ; then
    read -s -r -p "Enter password for preceding Oracle single sign-on userid: " ORC_SSOPSW
fi

read -s -r -p "Enter password for WebLogic Server and Runtime Deployment Tooling encryption: " WDT_RUNTIMEPSW
WLS_PSW=${WDT_RUNTIMEPSW}


# get OWNER_REPONAME if not set at the beginning of this file
if [ "$OWNER_REPONAME" == '' ] ; then
    read -r -p "Enter owner/reponame (blank for upsteam of current fork): " OWNER_REPONAME
fi

if [ -z "${OWNER_REPONAME}" ] ; then
    GH_FLAGS=""
else
    GH_FLAGS="--repo ${OWNER_REPONAME}"
fi

DISAMBIG_PREFIX=${DISAMBIG_PREFIX}`date +%m%d`
SERVICE_PRINCIPAL_NAME=${DISAMBIG_PREFIX}sp

# get default location if not set at the beginning of this file
if [ "$LOCATION" == '' ] ; then
    {
      az config get defaults.location --only-show-errors > /dev/null 2>&1
      LOCATION_DEFAULTS_SETUP=$?
    } || {
      LOCATION_DEFAULTS_SETUP=0
    }
    # if no default location is set, fallback to "eastus"
    if [ "$LOCATION_DEFAULTS_SETUP" -eq 1 ]; then
      LOCATION=eastus
    else
      LOCATION=$(az config get defaults.location --only-show-errors | jq -r .value)
    fi
fi

# Check AZ CLI status
msg "${GREEN}(1/6) Checking Azure CLI status...${NOFORMAT}"
{
  az > /dev/null
} || {
  msg "${RED}Azure CLI is not installed."
  msg "${GREEN}Go to https://aka.ms/nubesgen-install-az-cli to install Azure CLI."
  exit 1;
}
{
  az account show > /dev/null
} || {
  msg "${RED}You are not authenticated with Azure CLI."
  msg "${GREEN}Run \"az login\" to authenticate."
  exit 1;
}

msg "${YELLOW}Azure CLI is installed and configured!"

# Check GitHub CLI status
msg "${GREEN}(2/6) Checking GitHub CLI status...${NOFORMAT}"
USE_GITHUB_CLI=false
{
  gh auth status && USE_GITHUB_CLI=true && msg "${YELLOW}GitHub CLI is installed and configured!"
} || {
  msg "${YELLOW}Cannot use the GitHub CLI. ${GREEN}No worries! ${YELLOW}We'll set up the GitHub secrets manually."
  USE_GITHUB_CLI=false
}

# Execute commands
msg "${GREEN}(3/6) Create Azure credentials ${SERVICE_PRINCIPAL_NAME}"
SUBSCRIPTION_ID=$(az account show --query id --output tsv --only-show-errors)

### AZ ACTION CREATE

AZURE_CREDENTIALS=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors)
SP_ID=$( az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query \[0\].id -o tsv)
az role assignment create --assignee ${SP_ID} --scope="/subscriptions/${SUBSCRIPTION_ID}" --role "User Access Administrator"

msg "${GREEN}(6/6) Create secrets in GitHub"
if $USE_GITHUB_CLI; then
  {
    msg "${GREEN}Using the GitHub CLI to set secrets.${NOFORMAT}"
    gh ${GH_FLAGS} secret set AKS_REPO_USER_NAME -b"${AKS_REPO_USER_NAME}"
    gh ${GH_FLAGS} secret set AZURE_CREDENTIALS -b"${AZURE_CREDENTIALS}"
    msg "${YELLOW}\"AZURE_CREDENTIALS\""
    msg "${GREEN}${AZURE_CREDENTIALS}"
    gh ${GH_FLAGS} secret set DB_PASSWORD -b"${DB_PASSWORD}"
    gh ${GH_FLAGS} secret set ORC_SSOPSW -b"${ORC_SSOPSW}"
    gh ${GH_FLAGS} secret set ORC_SSOUSER -b"${ORC_SSOUSER}"
    gh ${GH_FLAGS} secret set WDT_RUNTIMEPSW -b"${WDT_RUNTIMEPSW}"
    gh ${GH_FLAGS} secret set WLS_PSW -b"${WLS_PSW}"    
    gh ${GH_FLAGS} secret set WLS_USERNAME -b"${WLS_USERNAME}"
    msg "${YELLOW}\"DISAMBIG_PREFIX\""
    msg "${GREEN}${DISAMBIG_PREFIX}"
  } || {
    USE_GITHUB_CLI=false
  }
fi
if [ $USE_GITHUB_CLI == false ]; then
  msg "${NOFORMAT}======================MANUAL SETUP======================================"
  msg "${GREEN}Using your Web browser to set up secrets..."
  msg "${NOFORMAT}Go to the GitHub repository you want to configure."
  msg "${NOFORMAT}In the \"settings\", go to the \"secrets\" tab and the following secrets:"
  msg "(in ${YELLOW}yellow the secret name and${NOFORMAT} in ${GREEN}green the secret value)"
  msg "${YELLOW}\"AKS_REPO_USER_NAME\""
  msg "${GREEN}${AKS_REPO_USER_NAME}"
  msg "${YELLOW}\"AZURE_CREDENTIALS\""
  msg "${GREEN}${AZURE_CREDENTIALS}"
  msg "${YELLOW}\"DB_PASSWORD\""
  msg "${GREEN}${DB_PASSWORD}"
  msg "${YELLOW}\"ORC_SSOPSW\""
  msg "${GREEN}${ORC_SSOPSW}"
  msg "${YELLOW}\"ORC_SSOUSER\""
  msg "${GREEN}${ORC_SSOUSER}"
  msg "${YELLOW}\"WDT_RUNTIMEPSW\""
  msg "${GREEN}${WDT_RUNTIMEPSW}"
  msg "${YELLOW}\"WLS_PSW\""
  msg "${GREEN}${WLS_PSW}"
  msg "${YELLOW}\"WLS_USERNAME\""
  msg "${GREEN}${WLS_USERNAME}"
  msg "${YELLOW}\"DISAMBIG_PREFIX\""
  msg "${GREEN}${DISAMBIG_PREFIX}"
  msg "${NOFORMAT}========================================================================"
fi
msg "${GREEN}Secrets configured"
