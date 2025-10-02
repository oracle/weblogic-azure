#!/usr/bin/env bash
set -Eeuo pipefail

echo "teardown-credentials.sh - Start"

 # remove param the json
 yq '.[]' "$param_file" | jq -c '.' | while read -r line; do
    name=$(echo "$line" | jq -r '.name')
    value=$(echo "$line" | jq -r '.value')
    gh secret --repo $(gh repo set-default --view) delete "$name"
done

echo "teardown-credentials.sh - Finish"
