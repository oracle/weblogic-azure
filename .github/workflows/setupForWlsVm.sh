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
# Three letters to disambiguate names.
DISAMBIG_PREFIX=
# URI (hostname:port) for Elastic server, leave blank if you don't want to integrate ELK.
ELK_URI=
# Account name for Elastic server, leave blank if you don't want to integrate ELK.
ELK_USER_NAME=
# Account password for Elastic server, leave blank if you don't want to integrate ELK.
ELK_PSW= 
# The location of the resource group. For example `eastus`. Leave blank to use your default location.
LOCATION=
# Oracle single sign-on userid.
OTN_USERID=
# Password for preceding Oracle single sign-on userid.
OTN_PASSWORD=
# User Email of GitHub acount to access GitHub repository.
USER_EMAIL=
# User name for preceding GitHub account.
USER_NAME=
# Personal token for preceding GitHub account.
GIT_TOKEN=
WLS_PSW=

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
read -r -p "Enter owner/reponame (blank for upsteam of current fork): " OWNER_REPONAME

if [ "$DISAMBIG_PREFIX" == '' ] ; then
    msg "${RED}You must enter a disambiguation prefix."
    exit 1;
fi

if [ -z "${OWNER_REPONAME}" ] ; then
    GH_FLAGS=""
else
    GH_FLAGS="--repo ${OWNER_REPONAME}"
fi

# get OTN_USERID if not set at the beginning of this file
if [ "$OTN_USERID" == '' ] ; then
    read -r -p "Enter Oracle single sign-on userid: " OTN_USERID
fi

# get OTN_PASSWORD if not set at the beginning of this file
if [ "$OTN_PASSWORD" == '' ] ; then
    read -s -r -p "Enter password for preceding Oracle single sign-on userid: " OTN_PASSWORD
fi

# get USER_EMAIL if not set at the beginning of this file
if [ "$USER_EMAIL" == '' ] ; then
    read -r -p "Enter user Email of GitHub acount to access GitHub repository: " USER_EMAIL
fi

# get USER_NAME if not set at the beginning of this file
if [ "$USER_NAME" == '' ] ; then
    read -r -p "Enter user name of GitHub account: " USER_NAME
fi

# get GIT_TOKEN if not set at the beginning of this file
if [ "$GIT_TOKEN" == '' ] ; then
    read -s -r -p "Enter personal token of GitHub account: " GIT_TOKEN
fi

read -s -r -p "Enter password for WebLogic Server: " WLS_PSW

# get ELK_URI if not set at the beginning of this file
if [ "$ELK_URI" == '' ] ; then
    read -r -p "Enter URI (hostname:port) for Elastic server, leave blank if you don't want to integrate ELK.: " ELK_URI
fi

# get ELK_USER_NAME if not set at the beginning of this file
if [ "$ELK_USER_NAME" == '' ] ; then
    read -r -p "Enter account name for Elastic server, leave blank if you don't want to integrate ELK.: " ELK_USER_NAME
fi

# get ELK_USER_NAME if not set at the beginning of this file
if [ "$ELK_PSW" == '' ] ; then
    read -s -r -p "Enter account password for Elastic server, leave blank if you don't want to integrate ELK.: " ELK_PSW
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
msg "${GREEN}(3/6) Create service principal and Azure credentials ${SERVICE_PRINCIPAL_NAME}"
SUBSCRIPTION_ID=$(az account show --query id --output tsv --only-show-errors)

### AZ ACTION CREATE

SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 -w0)
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

msg "${GREEN}(6/6) Create secrets in GitHub"
if $USE_GITHUB_CLI; then
  {
    msg "${GREEN}Using the GitHub CLI to set secrets.${NOFORMAT}"
    gh ${GH_FLAGS} secret set AZURE_CREDENTIALS -b"${AZURE_CREDENTIALS}"
    msg "${YELLOW}\"AZURE_CREDENTIALS\""
    msg "${GREEN}${AZURE_CREDENTIALS}"
    gh ${GH_FLAGS} secret set ELK_PSW -b"${ELK_PSW}"
    gh ${GH_FLAGS} secret set ELK_URI -b"${ELK_URI}"
    gh ${GH_FLAGS} secret set ELK_USER_NAME -b"${ELK_USER_NAME}"
    gh ${GH_FLAGS} secret set GIT_TOKEN -b"${GIT_TOKEN}"
    gh ${GH_FLAGS} secret set OTN_PASSWORD -b"${OTN_PASSWORD}"
    gh ${GH_FLAGS} secret set OTN_USERID -b"${OTN_USERID}"
    gh ${GH_FLAGS} secret set USER_EMAIL -b"${USER_EMAIL}"
    gh ${GH_FLAGS} secret set USER_NAME -b"${USER_NAME}"
    gh ${GH_FLAGS} secret set WLS_PSW -b"${WLS_PSW}"
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
  msg "${YELLOW}\"AZURE_CREDENTIALS\""
  msg "${GREEN}${AZURE_CREDENTIALS}"
  msg "${YELLOW}\"OTN_USERID\""
  msg "${GREEN}${OTN_USERID}"
  msg "${YELLOW}\"OTN_PASSWORD\""
  msg "${GREEN}${OTN_PASSWORD}"
  msg "${YELLOW}\"USER_EMAIL\""
  msg "${GREEN}${USER_EMAIL}"
  msg "${YELLOW}\"USER_NAME\""
  msg "${GREEN}${USER_NAME}"
  msg "${YELLOW}\"GIT_TOKEN\""
  msg "${GREEN}${GIT_TOKEN}"
  msg "${YELLOW}\"ELK_URI\""
  msg "${GREEN}${ELK_URI}"
  msg "${YELLOW}\"ELK_USER_NAME\""
  msg "${GREEN}${ELK_USER_NAME}"
  msg "${YELLOW}\"ELK_PSW\""
  msg "${GREEN}${ELK_PSW}"
  msg "${YELLOW}\"WLS_PSW\""
  msg "${GREEN}${WLS_PSW}"
  msg "${YELLOW}\"DISAMBIG_PREFIX\""
  msg "${GREEN}${DISAMBIG_PREFIX}"
  msg "${NOFORMAT}========================================================================"
fi
msg "${GREEN}Secrets configured"
