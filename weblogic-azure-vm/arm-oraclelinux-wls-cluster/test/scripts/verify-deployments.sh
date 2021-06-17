#!/bin/bash

# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# Description
# This scipt is to deploy the Azure deployments based on test parameters created.

prefix="$1"
location="$2"
template="$3"
githubUserName="$4"
testbranchName="$5"
scriptsDir="$6"

groupName=${prefix}-preflight
keyVaultName=keyvault${prefix}
certDataName=certData
certPasswordName=certPassword

# create SSL certificate for Azure Application Gateway
openssl genrsa -passout pass:GEN-UNIQUE -out privkey.pem 3072
openssl req -x509 -new -key privkey.pem -out privkey.pub -subj "/C=US"
openssl pkcs12 -passout pass:GEN-UNIQUE -export -in privkey.pub -inkey privkey.pem -out mycert.pfx

# create Azure resources for preflight testing
az group create --verbose --name $groupName --location ${location}
az keyvault create -n ${keyVaultName} -g ${groupName} -l ${location}
az keyvault update -n ${keyVaultName} -g ${groupName} --enabled-for-template-deployment true
az keyvault secret set --vault-name ${keyVaultName} -n ${certDataName} --file mycert.pfx --encoding base64
az keyvault secret set --vault-name ${keyVaultName} -n ${certPasswordName} --value GEN-UNIQUE

# generate parameters for testing differnt cases
parametersList=()
# parameters for cluster
bash ${scriptsDir}/gen-parameters.sh ${scriptsDir}/parameters.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters.json)

# parameters for cluster+db
bash ${scriptsDir}/gen-parameters-db.sh ${scriptsDir}/parameters-db.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters-db.json)

# parameters for cluster+aad
bash ${scriptsDir}/gen-parameters-aad.sh ${scriptsDir}/parameters-aad.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters-aad.json)

# parameters for cluster+coherence
bash ${scriptsDir}/gen-parameters-elk.sh ${scriptsDir}/parameters-coherence.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters-coherence.json)

# parameters for cluster+elk
bash ${scriptsDir}/gen-parameters-elk.sh ${scriptsDir}/parameters-elk.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters-elk.json)

# parameters for cluster+db+aad
bash ${scriptsDir}/gen-parameters-db-aad.sh ${scriptsDir}/parameters-db-aad.json $githubUserName $testbranchName
parametersList+=(${scriptsDir}/parameters-db-aad.json)

# parameters for cluster+ag
bash ${scriptsDir}/gen-parameters-ag.sh ${scriptsDir}/parameters-ag.json $githubUserName $testbranchName \
    ${keyVaultName} ${groupName} ${certDataName} ${certPasswordName}
parametersList+=(${scriptsDir}/parameters-ag.json)

# parameters for cluster+db+ag
bash ${scriptsDir}/gen-parameters-db-ag.sh ${scriptsDir}/parameters-db-ag.json $githubUserName $testbranchName \
    ${keyVaultName} ${groupName} ${certDataName} ${certPasswordName}
parametersList+=(${scriptsDir}/parameters-db-ag.json)

# parameters for cluster+aad+ag
bash ${scriptsDir}/gen-parameters-aad-ag.sh ${scriptsDir}/parameters-aad-ag.json $githubUserName $testbranchName \
    ${keyVaultName} ${groupName} ${certDataName} ${certPasswordName}
parametersList+=(${scriptsDir}/parameters-aad-ag.json)

# parameters for cluster+db+aad+ag
bash ${scriptsDir}/gen-parameters-db-aad-ag.sh ${scriptsDir}/parameters-db-aad-ag.json $githubUserName $testbranchName \
    ${keyVaultName} ${groupName} ${certDataName} ${certPasswordName}
parametersList+=(${scriptsDir}/parameters-db-aad-ag.json)

# run preflight tests
success=true
for parameters in "${parametersList[@]}";
do
    az deployment group validate -g ${groupName} -f ${template} -p @${parameters} --no-prompt
    if [[ $? != 0 ]]; then
        echo "deployment validation for ${parameters} failed!"
        success=false
    fi
done

# release Azure resources
az group delete --yes --no-wait --verbose --name $groupName

if [[ $success == "false" ]]; then
    exit 1
else
    exit 0
fi
