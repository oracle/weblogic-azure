# Copyright (c) 2021, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
# This script runs on Azure Container Instance with Alpine Linux that Azure Deployment script creates.

function validate_app() {
    # make sure all the application are active, if not, fail the deployment.
    local wlsDomainNS="${WLS_DOMAIN_UID}-ns"
    local wlsAdminSvcName="${WLS_DOMAIN_UID}-admin-server"
    scriptCheckAppStatus=$scriptDir/checkApplicationStatus.py
    chmod ugo+x $scriptDir/checkApplicationStatus.py
    utility_validate_application_status \
        ${wlsDomainNS} \
        ${wlsAdminSvcName} \
        ${WLS_DOMAIN_USER} \
        ${WLS_DOMAIN_PASSWORD} \
        ${scriptCheckAppStatus}
}

# Main script
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

source ${scriptDir}/common.sh
source ${scriptDir}/utility.sh

install_kubectl

connect_aks $AKS_NAME $AKS_RESOURCE_GROUP_NAME

validate_app