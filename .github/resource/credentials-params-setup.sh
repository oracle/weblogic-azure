#!/usr/bin/env bash
set -Eeuo pipefail

# ANSI color codes
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "setup-credentials.sh - Start"

# Function to print error messages in red
print_error() {
    local message=$1
    echo -e "${RED}Error: ${message}${NC}"
}

check_parameters() {
    echo "Checking parameters..."
    local has_empty_value=0

    while IFS= read -r line; do
        name=$(echo "$line" | yq -r '.name')
        value=$(echo "$line" | yq -r '.value')

        if [ -z "$value" ] || [ "$value" == "null" ]; then
            print_error "The parameter '$name' has an empty/null value. Please provide a valid value."
            has_empty_value=1
            break
        else
            echo "Name: $name, Value: $value"
        fi
    done < <(yq eval -o=json '.[]' "$param_file" | jq -c '.')

    echo "return $has_empty_value"
    return $has_empty_value
}

# Function to set values from YAML
set_values() {
    echo "Setting values..."
    yq eval -o=json '.[]' "$param_file" | jq -c '.' | while read -r line; do
        name=$(echo "$line" | jq -r '.name')
        value=$(echo "$line" | jq -r '.value')
        gh secret --repo $(gh repo set-default --view) set "$name" -b"${value}"
    done
}

# Main script execution
main() {
    if check_parameters; then
        echo "All parameters are valid."
        set_values
    else
        echo "Parameter check failed. Exiting."
        exit 1
    fi

    echo "setup-credentials.sh - Finish"
}

# Run the main function
main
