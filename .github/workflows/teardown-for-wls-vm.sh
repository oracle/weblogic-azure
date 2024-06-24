#!/usr/bin/env bash

################################################
# This script is invoked by a human who:
# - can remove repository secrets in the github repo from which this file was cloned.
# - has the gh client >= 2.0.0 installed.
# - has yq 4.x installed.
#
# This script initializes the repo from which this file is was cloned
# with the necessary secrets to run the workflows.
# Steps to run the Script:
# 1. Run gh auth login.
# 2. Clone the repository.
# 3. Run the script with the following command:
#    ```
#    cd .github/workflows
#    bash teardown-for-wls-vm.sh
#    ```
# 4. The script will remove the required secrets in the repository.
# 5. Check the repository secrets to verify that the secrets are removed.
################################################

set -Eeuo pipefail

source ../resource/pre-check.sh
## Set environment variables
export param_file="../resource/credentials-params.yaml"

source ../resource/teardown.sh


