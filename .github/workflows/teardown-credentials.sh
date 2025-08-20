#!/usr/bin/env bash

################################################
# This script is invoked by a human who:
# - can remove repository secrets and variables in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
# - has yq 4.x installed.
#
# This script removes all secrets and variables set by setup-credentials.sh.
# Steps to run the Script:
# 1. Run gh auth login.
# 2. Clone the repository.
# 3. Run the script with the following command:
#    ```
#    cd .github/workflows
#    bash teardown-credentials.sh
#    ```
# 4. The script will remove the required secrets and variables in the repository.
# 5. Check the repository secrets/variables to verify that they are removed.
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

# Remove all secrets set by setup-credentials.sh
source "${RESOURCE_DIR}/credentials-params-teardown.sh"
source "${RESOURCE_DIR}/azure-credential-teardown.sh"

echo "All unified secrets and variables have been removed."
exit 0
