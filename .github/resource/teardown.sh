#!/usr/bin/env bash
set -Eeuo pipefail

echo "teardown-credentials.sh - Start"

# remove param the json
yq eval -o=json '.[]' "$param_file" | jq -c '.' | while read -r line; do
    name=$(echo "$line" | jq -r '.name')
    value=$(echo "$line" | jq -r '.value')
    gh secret remove "$name"
done

echo "teardown-credentials.sh - Finish"
