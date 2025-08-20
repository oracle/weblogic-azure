#!/usr/bin/env bash

################################################
# This script is invoked by a human who:
# - has done az login.
# - can create repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
# - has yq 4.x installed.
#
# This script initializes the repo from which this file was cloned
# with the necessary secrets to run the workflows.
# Steps to run the Script:
# 1. Run az login.
# 2. Run gh auth login.
# 3. Clone the repository.
# 4. Prepare the .github/resource/credentials-params.yaml file with the required parameters.
# 5. Run the script with the following command:
#    ```
#    cd .github/workflows
#    bash setup-credentials.sh
#    ```
# 6. The script will set the required secrets in the repository.
# 7. Check the repository secrets to verify that the secrets are set.
################################################

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="${SCRIPT_DIR}/../resource"
export param_file="${RESOURCE_DIR}/credentials-params.yaml"

source "${RESOURCE_DIR}/pre-check.sh"

if [[ ! -f "${param_file}" ]]; then
  echo "Parameter file not found: ${param_file}" >&2
  exit 1
fi

source "${RESOURCE_DIR}/credentials-params-setup.sh"
source "${RESOURCE_DIR}/azure-credential-setup.sh"

exit 0
